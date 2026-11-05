# Арт для анимированного лука 0.5.0

Режим: встроенный image_gen (редактирование), transparent_background=true. Источник: app/assets/arena/windranger.png. Результат: app/assets/arena/windranger-rig.png. Оригинал сохранён. Локальное изображение было открыто до редактирования. Отдельно от арта в коде построены тетива, стрела, пружины и 2D-деформация. Полноценные 3D-модели не создавались.

## Промпт

Use case: precise-object-edit. Edit target: the provided full-body Windranger archer transparent game sprite. Prepare this exact sprite for code-driven 2D bow animation. REMOVE ONLY the taut bowstring, the entire nocked arrow shaft, arrowhead, and ALL green glowing energy/light around the arrow. Leave the beautiful gold/wood bow itself, both hands and fingers, arms, face, hair, cloak, costume, boots and exact aiming pose completely unchanged. Her pulling hand near her cheek should remain with fingers ready to pinch a string that will be drawn in code. Cleanly reconstruct tiny underlying costume details where the removed arrow or string crossed them. Keep original composition, proportions and full-body framing. Transparent alpha background. No floor, text, added objects, duplicate limbs, new pose, or residual green glowing arrow.
