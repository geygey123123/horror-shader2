#version 120

// ============================================================================
// MINIMAL TEST SHADER - Fragment Shader
// ТЕСТОВЫЙ ШЕЙДЕР: Должен сделать всё изображение ЧЁРНО-БЕЛЫМ
// Если это работает - значит шейдер подключился правильно
// ============================================================================

varying vec2 texcoord;

uniform sampler2D gtexture;
uniform sampler2D colortex0;
uniform float viewTime;
uniform float frameTimeCounter;
uniform vec2 aspectRatio;

void main() {
    // Получаем цвет пикселя из текстуры
    vec4 color = texture2D(gtexture, texcoord);
    
    // Если gtexture пустой, пробуем colortex0
    if (color.a < 0.1) {
        color = texture2D(colortex0, texcoord);
    }
    
    // Конвертируем в чёрно-белое (полная десатурация)
    float gray = dot(color.rgb, vec3(0.299, 0.587, 0.114));
    
    // Инвертируем цвета для теста (небо станет чёрным, земля - белой)
    // Это ГАРАНТИРОВАННО покажет, что шейдер работает
    vec3 testColor = vec3(gray);
    
    // Добавляем красный оттенок для явного визуального отличия
    testColor.r = min(testColor.r + 0.3, 1.0);
    
    gl_FragColor = vec4(testColor, 1.0);
}
