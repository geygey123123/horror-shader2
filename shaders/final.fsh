#version 120

// ============================================================================
// ANALOG HORROR SHADER - Fragment Shader (final.fsh)
// Стиль: VHS / Found Footage / Analog Horror
// Совместимость: OptiFine и Iris Shaders
// ============================================================================

// ----------------------------------------------------------------------------
// НАСТРОЙКИ ИНТЕНСИВНОСТИ ЭФФЕКТОВ (измените значения для настройки)
// ----------------------------------------------------------------------------
#define CRT_DISTORTION_STRENGTH 0.015    // Искажение линзы (0.0 = нет, 0.03 = сильное)
#define CHROMATIC_ABERRATION_STRENGTH 0.004  // Хроматическая аберрация (0.0-0.01)
#define NOISE_INTENSITY 0.12             // Интенсивность шума (0.0-0.3)
#define SCANLINE_INTENSITY 0.18          // Яркость сканлайнов (0.0-0.4)
#define GLITCH_FREQUENCY 0.03            // Частота глитчей (0.0-0.1)
#define GLITCH_STRENGTH 0.02             // Сила глитч-сдвига (0.0-0.05)
#define VIGNETTE_STRENGTH 0.75           // Сила виньетки (0.0-1.0)
#define DESATURATION_AMOUNT 0.65         // Десатурация цвета (0.0-1.0)
#define CONTRAST_DARKS 1.3               // Контраст в тенях (1.0-2.0)
#define COLOR_TINT_R 1.0                 // Тонирование: красный канал
#define COLOR_TINT_G 0.92                // Тонирование: зеленый (грязный оттенок)
#define COLOR_TINT_B 0.85                // Тонирование: синий канал
#define BASE_BRIGHTNESS 0.7              // Базовая яркость мира (0.3-1.0)
#define FOG_DENSITY 0.0                  // Плотность тумана (настраивается отдельно)

// ----------------------------------------------------------------------------
// UNIFORM VARIABLES
// ----------------------------------------------------------------------------
uniform sampler2D gaux4;        // Основной буфер цвета (цвет сцены)
uniform sampler2D colortex0;    // Альтернативный буфер цвета
uniform float viewTime;         // Время просмотра (секунды)
uniform float frameTimeCounter; // Счётчик кадров
uniform vec2 aspectRatio;       // Соотношение сторон экрана
uniform int frameCounter;       // Счётчик кадров (для детерминированного шума)

varying vec2 texcoord;

// ----------------------------------------------------------------------------
// МАТЕМАТИЧЕСКИЕ ФУНКЦИИ
// ----------------------------------------------------------------------------

// Псевдослучайная функция на основе координат и времени
float random(vec2 st, float time) {
    return fract(sin(dot(st.xy + time, vec2(12.9898, 78.233))) * 43758.5453123);
}

// Значение шума для пикселя (использует frameCounter для анимации)
float noise(vec2 st, float time) {
    vec2 i = floor(st);
    vec2 f = fract(st);
    
    // Четыре угла тайла
    float a = random(i, floor(time * 60.0));
    float b = random(i + vec2(1.0, 0.0), floor(time * 60.0));
    float c = random(i + vec2(0.0, 1.0), floor(time * 60.0));
    float d = random(i + vec2(1.0, 1.0), floor(time * 60.0));
    
    // Интерполяция
    vec2 u = f * f * (3.0 - 2.0 * f);
    
    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

// Быстрый шум для зернистости пленки
float filmGrain(vec2 st, float time) {
    return random(st + time, time) * 2.0 - 1.0;
}

// Функция для сканлайнов (горизонтальные полосы)
float scanlines(vec2 st, float time) {
    float scanline = sin(st.y * 800.0 + time * 2.0);
    scanline = scanline * 0.5 + 0.5;
    return 1.0 - (scanline * SCANLINE_INTENSITY);
}

// CRT дисторсия (эффект выпуклого экрана)
vec2 crtDistortion(vec2 uv, vec2 center) {
    vec2 dc = uv - center;
    float dist = dot(dc, dc);
    
    // Кубическое искажение для эффекта "рыбьего глаза"
    vec2 distorted = uv + dc * (dist * CRT_DISTORTION_STRENGTH);
    
    // Ограничиваем координаты
    distorted = clamp(distorted, 0.0, 1.0);
    
    return distorted;
}

// Глитч-эффект (случайные горизонтальные сдвиги строк)
float glitchOffset(vec2 uv, float time) {
    // Детерминированный "шум" на основе Y-координаты и времени
    float glitchNoise = random(vec2(floor(uv.y * 100.0), floor(time * 10.0)), time);
    
    // Активируем глитч только когда шум превышает порог
    if (glitchNoise > (1.0 - GLITCH_FREQUENCY)) {
        return (random(vec2(floor(uv.y * 50.0), floor(time * 5.0)), time) - 0.5) * GLITCH_STRENGTH;
    }
    return 0.0;
}

// Виньетирование (затемнение по краям)
float vignette(vec2 uv, vec2 center) {
    vec2 toCenter = uv - center;
    float dist = length(toCenter);
    float vig = 1.0 - smoothstep(0.3, 0.9, dist * VIGNETTE_STRENGTH);
    return vig;
}

// Десатурация цвета
vec3 desaturate(vec3 color, float amount) {
    float gray = dot(color, vec3(0.299, 0.587, 0.114));
    return mix(color, vec3(gray), amount);
}

// Коррекция контраста в тенях
vec3 contrastDarks(vec3 color, float contrast) {
    vec3 adjusted = pow(color, vec3(1.0 / contrast));
    return adjusted;
}

// ----------------------------------------------------------------------------
// ОСНОВНАЯ ФУНКЦИЯ
// ----------------------------------------------------------------------------
void main() {
    // Нормализованные координаты текстуры [0, 1]
    vec2 uv = texcoord;
    
    // Центр экрана (учитывает соотношение сторон)
    vec2 center = vec2(0.5, 0.5 * aspectRatio.y / aspectRatio.x);
    if (aspectRatio.x > aspectRatio.y) {
        center = vec2(0.5, 0.5);
    } else {
        center = vec2(0.5 * aspectRatio.x / aspectRatio.y, 0.5);
    }
    
    // Применяем CRT дисторсию к координатам
    vec2 distortedUV = crtDistortion(uv, center);
    
    // Добавляем глитч-смещение
    float glitchX = glitchOffset(distortedUV, viewTime);
    distortedUV.x += glitchX;
    
    // Ограничиваем координаты после всех искажений
    distortedUV = clamp(distortedUV, 0.001, 0.999);
    
    // ------------------------------------------------------------------------
    // ВЫБОРКА ЦВЕТА С ХРОМАТИЧЕСКОЙ АБЕРРАЦИЕЙ
    // ------------------------------------------------------------------------
    // Разделяем RGB каналы со сдвигом в противоположные стороны
    
    vec2 aberrationOffset = (uv - center) * CHROMATIC_ABERRATION_STRENGTH;
    
    // Выборка каждого канала с разным смещением
    float r = texture2D(gaux4, distortedUV + aberrationOffset).r;
    float g = texture2D(gaux4, distortedUV).g;
    float b = texture2D(gaux4, distortedUV - aberrationOffset).b;
    
    vec3 color = vec3(r, g, b);
    
    // Если gaux4 недоступен, пробуем colortex0
    if (color == vec3(0.0)) {
        r = texture2D(colortex0, distortedUV + aberrationOffset).r;
        g = texture2D(colortex0, distortedUV).g;
        b = texture2D(colortex0, distortedUV - aberrationOffset).b;
        color = vec3(r, g, b);
    }
    
    // ------------------------------------------------------------------------
    // ПРИМЕНЕНИЕ ЭФФЕКТОВ ПОСТ-ОБРАБОТКИ
    // ------------------------------------------------------------------------
    
    // 1. Базовое затемнение мира
    color *= BASE_BRIGHTNESS;
    
    // 2. Наложение шума (VHS grain)
    float grain = filmGrain(uv, viewTime + frameTimeCounter);
    color += grain * NOISE_INTENSITY;
    
    // 3. Сканлайны
    float scanlineFactor = scanlines(uv, viewTime);
    color *= scanlineFactor;
    
    // 4. Виньетирование
    float vig = vignette(uv, center);
    color *= vig;
    
    // 5. Десатурация
    color = desaturate(color, DESATURATION_AMOUNT);
    
    // 6. Повышение контраста в тенях
    color = contrastDarks(color, CONTRAST_DARKS);
    
    // 7. Цветовое тонирование (грязный зелено-желтый оттенок)
    color.r *= COLOR_TINT_R;
    color.g *= COLOR_TINT_G;
    color.b *= COLOR_TINT_B;
    
    // 8. Дополнительное затемнение по краям для клаустрофобии
    float edgeDarkness = 1.0 - (vig * 0.5);
    color *= edgeDarkness;
    
    // ------------------------------------------------------------------------
    // ФИНАЛЬНЫЙ ВЫВОД
    // ------------------------------------------------------------------------
    
    // Ограничиваем значения цвета
    color = clamp(color, 0.0, 1.0);
    
    gl_FragColor = vec4(color, 1.0);
}
