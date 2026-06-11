#!/usr/bin/env node

const net = require('net');
const path = require('path');
const fs = require('fs');
const os = require('os');
const { spawn, execSync } = require('child_process');
const { Readable } = require('stream');

const SOCKET_PATH = '/tmp/keyclick.sock';
const SOUNDS_DIR = path.join(os.homedir(), 'Sounds', 'karabiner');
const DEFAULT_SOUND = 'enter_sniper_rifle_fire.mp3';

// Инициализация библиотек для резидентного воспроизведения
let Speaker, WavReader, ffmpegPath;
try {
    Speaker = require('speaker');
    WavReader = require('node-wav');
    
    // Инициализация ffmpeg для декодирования MP3
    try {
        const ffmpegInstaller = require('@ffmpeg-installer/ffmpeg');
        ffmpegPath = ffmpegInstaller.path;
    } catch (error) {
        // Пробуем найти ffmpeg в системе
        ffmpegPath = 'ffmpeg';
    }
    
    console.log('Resident audio player initialized');
} catch (error) {
    console.error('Failed to load audio libraries:', error.message);
    Speaker = null;
}

// Звуковые буферы: храним декодированные PCM данные в памяти
// Формат: { buffer: Buffer, sampleRate: number, channels: number, bitDepth: number }
const soundBuffers = new Map();

// Функция для разрешения macOS алиасов в реальные пути
function resolveAlias(aliasPath) {
    try {
        // Сначала пробуем разрешить как symlink (быстрый способ)
        const realPath = fs.realpathSync(aliasPath);
        if (realPath !== aliasPath) {
            return realPath;
        }
        
        // Если это macOS алиас, используем osascript
        const script = `tell application "Finder" to get POSIX path of (original item of alias POSIX file "${aliasPath}" as text)`;
        const result = execSync(`osascript -e '${script}'`, { 
            encoding: 'utf8',
            timeout: 1000 // Таймаут 1 секунда
        });
        return result.trim();
    } catch (error) {
        // Если не получилось разрешить, возвращаем исходный путь
        return aliasPath;
    }
}

// Все активные воспроизведения (для остановки всех при команде stop)
const activePlaybacks = new Set();

// Загрузка и декодирование звуковых файлов в PCM буферы
async function loadSounds() {
    try {
        if (!fs.existsSync(SOUNDS_DIR)) {
            console.error(`Sounds directory not found: ${SOUNDS_DIR}`);
            return;
        }

        const files = fs.readdirSync(SOUNDS_DIR);
        // Загружаем все файлы, игнорируя скрытые файлы (начинающиеся с точки)
        const audioFiles = files.filter(f => !f.startsWith('.'));

        console.log(`Loading ${audioFiles.length} audio file(s)...`);

        for (const file of audioFiles) {
            let filePath = path.join(SOUNDS_DIR, file);
            try {
                // Разрешаем алиасы и symlinks в реальный путь
                filePath = resolveAlias(filePath);
                
                // Пропускаем директории
                const stat = fs.statSync(filePath);
                if (stat.isDirectory()) {
                    continue;
                }
                
                // Пробуем загрузить через ffmpeg (поддерживает все форматы и автоопределение)
                await loadAudioFile(file, filePath);
                console.log(`✓ Loaded: ${file}`);
            } catch (error) {
                console.error(`✗ Failed to load ${file}: ${error.message}`);
            }
        }

        if (soundBuffers.size === 0) {
            console.warn(`No audio files loaded successfully`);
        } else {
            console.log(`Successfully loaded ${soundBuffers.size} sound(s) into memory`);
        }
    } catch (error) {
        console.error(`Error loading sounds: ${error.message}`);
    }
}

// Загрузка WAV файла напрямую
function loadWavFile(name, filePath) {
    return new Promise((resolve, reject) => {
        try {
            const wavBuffer = fs.readFileSync(filePath);
            const wav = WavReader.decode(wavBuffer);
            
            soundBuffers.set(name, {
                buffer: Buffer.from(wav.channelData[0]), // Используем первый канал
                sampleRate: wav.sampleRate,
                channels: wav.channelData.length,
                bitDepth: 16 // node-wav декодирует в 16-bit
            });
            resolve();
        } catch (error) {
            reject(error);
        }
    });
}

// Загрузка аудиофайла через ffmpeg (MP3, AIFF и т.д.)
function loadAudioFile(name, filePath) {
    return new Promise((resolve, reject) => {
        const chunks = [];
        let stderr = '';

        // Декодируем в PCM: 16-bit, 44100 Hz, моно
        const ffmpeg = spawn(ffmpegPath, [
            '-i', filePath,
            '-f', 's16le',      // 16-bit signed little-endian PCM
            '-ar', '44100',     // Sample rate
            '-ac', '1',         // Mono
            '-'                 // Вывод в stdout
        ], {
            stdio: ['ignore', 'pipe', 'pipe']
        });

        ffmpeg.stdout.on('data', (chunk) => {
            chunks.push(chunk);
        });

        ffmpeg.stderr.on('data', (data) => {
            stderr += data.toString();
        });

        ffmpeg.on('close', (code) => {
            if (code === 0) {
                const pcmBuffer = Buffer.concat(chunks);
                soundBuffers.set(name, {
                    buffer: pcmBuffer,
                    sampleRate: 44100,
                    channels: 1,
                    bitDepth: 16
                });
                resolve();
            } else {
                reject(new Error(`ffmpeg failed: ${stderr}`));
            }
        });

        ffmpeg.on('error', (error) => {
            reject(new Error(`ffmpeg spawn failed: ${error.message}`));
        });
    });
}

// Остановка всех активных воспроизведений
function stopCurrentPlayback() {
    // Останавливаем все активные воспроизведения
    for (const playback of activePlaybacks) {
        try {
            // Останавливаем поток
            if (playback.audioStream) {
                playback.audioStream.unpipe();
                playback.audioStream.destroy();
            }
            
            // Останавливаем speaker
            if (playback.speaker) {
                // Удаляем все слушатели
                playback.speaker.removeAllListeners();
                // Уничтожаем speaker - это должно мгновенно остановить воспроизведение
                playback.speaker.destroy();
                // Также пробуем закрыть underlying audio device
                if (typeof playback.speaker.close === 'function') {
                    playback.speaker.close();
                }
            }
        } catch (error) {
            // Игнорируем ошибки при остановке
        }
    }
    
    // Очищаем список активных воспроизведений
    activePlaybacks.clear();
}

// Воспроизведение звука через резидентный аудиопоток (без запуска процессов)
function playSound(soundName) {
    const soundData = soundBuffers.get(soundName) || soundBuffers.get(DEFAULT_SOUND);
    
    if (!soundData) {
        console.error(`Sound not found: ${soundName}`);
        return;
    }

    if (!Speaker) {
        console.error(`Speaker library not available`);
        return;
    }

    try {
        // Создаём новый Speaker для каждого воспроизведения
        // Speaker использует Core Audio напрямую, без запуска процессов
        const speaker = new Speaker({
            channels: soundData.channels,
            bitDepth: soundData.bitDepth,
            sampleRate: soundData.sampleRate
        });

        // Создаём поток из буфера и отправляем в Speaker
        const audioStream = new Readable();
        audioStream.push(soundData.buffer);
        audioStream.push(null); // Конец потока

        // Создаём объект воспроизведения
        const playback = { speaker, audioStream };
        
        // Добавляем в список активных воспроизведений
        activePlaybacks.add(playback);

        audioStream.pipe(speaker);

        // Функция для удаления из активных воспроизведений
        const cleanup = () => {
            activePlaybacks.delete(playback);
        };

        speaker.on('close', cleanup);
        speaker.on('finish', cleanup);
        speaker.on('error', (err) => {
            console.error(`Speaker error: ${err.message}`);
            cleanup();
        });
    } catch (error) {
        console.error(`Error playing sound: ${error.message}`);
    }
}

// Создание Unix socket сервера
function createServer() {
    // Удаляем старый socket если существует
    if (fs.existsSync(SOCKET_PATH)) {
        fs.unlinkSync(SOCKET_PATH);
    }

    const server = net.createServer((socket) => {
        socket.on('data', (data) => {
            const command = data.toString().trim();
            
            if (command === '-stop') {
                // Останавливаем воспроизведение
                stopCurrentPlayback();
                console.log('Playback stopped');
            } else if (command === '' || command === 'play') {
                // Воспроизводим дефолтный звук (пустая команда или legacy "play")
                playSound(DEFAULT_SOUND);
            } else {
                // Воспроизводим указанный звук (имя файла передано как есть)
                playSound(command);
            }
        });

        socket.on('error', (err) => {
            // Игнорируем ошибки закрытия соединения
            if (err.code !== 'ECONNRESET') {
                console.error(`Socket error: ${err.message}`);
            }
        });
    });

    server.listen(SOCKET_PATH, () => {
        console.log(`Audio daemon listening on ${SOCKET_PATH}`);
        // Устанавливаем права доступа на socket
        fs.chmodSync(SOCKET_PATH, 0o666);
    });

    server.on('error', (err) => {
        console.error(`Server error: ${err.message}`);
        process.exit(1);
    });

    // Обработка сигналов для корректного завершения
    process.on('SIGTERM', () => {
        console.log('Received SIGTERM, shutting down gracefully');
        server.close(() => {
            if (fs.existsSync(SOCKET_PATH)) {
                fs.unlinkSync(SOCKET_PATH);
            }
            process.exit(0);
        });
    });

    process.on('SIGINT', () => {
        console.log('Received SIGINT, shutting down gracefully');
        server.close(() => {
            if (fs.existsSync(SOCKET_PATH)) {
                fs.unlinkSync(SOCKET_PATH);
            }
            process.exit(0);
        });
    });
}

// Запуск демона
async function start() {
    console.log('Starting audio daemon...');
    
    // Загружаем звуки в память (асинхронно)
    await loadSounds();
    
    // Создаём socket сервер
    createServer();
}

start();
