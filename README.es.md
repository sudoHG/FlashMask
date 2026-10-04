# Flash Mask

[![Release](https://img.shields.io/github/v/release/sudoHG/FlashMask?style=flat-square&label=release)](https://github.com/sudoHG/FlashMask/releases/latest) [![Stars](https://img.shields.io/github/stars/sudoHG/FlashMask?style=flat-square&label=stars)](https://github.com/sudoHG/FlashMask/stargazers) [![License](https://img.shields.io/badge/license-Apache--2.0-blue?style=flat-square)](LICENSE) [![macOS](https://img.shields.io/badge/macOS-13%2B-black?style=flat-square)](https://apps.apple.com/es/app/flash-mask/id6803817818?mt=12) [![Universal](https://img.shields.io/badge/Universal-arm64%20%2B%20x86__64-black?style=flat-square)](https://apps.apple.com/es/app/flash-mask/id6803817818?mt=12) [![README views](https://hits.sh/github/sudoHG/FlashMask.svg?style=flat-square&label=README%20views)](https://hits.sh/github.com/sudoHG/FlashMask/)

**Máscaras de imagen rápidas que muestran a la IA exactamente dónde editar.**

<a href="https://apps.apple.com/es/app/flash-mask/id6803817818?mt=12"><img src="https://tools.applemediaservices.com/api/badges/download-on-the-mac-app-store/black/es-es?size=250x83" alt="Descargar en el Mac App Store" height="54"></a>

> «Eso no, lo de al lado». ¿Cuántas veces has tenido que decirle eso a la IA?  
> Quieres ajustar un solo detalle y el modelo regenera la imagen completa. Hasta ahora, solucionarlo implicaba abrir un editor de imágenes pesado para hacer selecciones y exportaciones tediosas.  
> Flash Mask reduce todo ese proceso a segundos: arrastra una imagen, delimita el área que quieres modificar y copia coordenadas JSON estructuradas directamente a tu IA o agente para que conozca la ubicación exacta de edición. Cuando necesites precisión a nivel de píxel, exporta una máscara en blanco y negro 1:1 con un solo clic.

![Flash Mask en macOS: Delimitando una región de la imagen y copiando coordenadas JSON para un agente de IA](assets/app-screenshot.png)

---

## Descripción general

Flash Mask es una aplicación complementaria nativa y ligera para macOS diseñada para la edición de imágenes con IA y flujos de trabajo visuales. Al colaborar con modelos de IA o agentes de programación, los prompts de texto por sí solos a menudo no logran especificar los límites exactos, lo que provoca cambios no deseados en toda la imagen o ediciones en el lugar equivocado.

En macOS, Flash Mask genera JSON 1.1 con una instrucción para toda la imagen y notas opcionales para regiones individuales. La aplicación web del sitio web se mantiene en JSON 1.0.

### App para Mac

- Pega una captura de pantalla directamente desde el portapapeles.
- Añade una instrucción para toda la imagen y notas opcionales para regiones individuales.
- Usa la interfaz en siete idiomas: inglés, chino simplificado, chino tradicional, japonés, alemán, francés y español.
- Utiliza una ventana de ajustes dedicada para cambiar de idioma, buscar actualizaciones y abrir el sitio web, la ayuda, el código fuente en GitHub o la página de soporte.

En lugar de lidiar con herramientas de lazo, capas de relleno y exportaciones manuales en editores de imágenes complejos, Flash Mask convierte tus selecciones en coordenadas listas para agentes en segundos:

- **Coordenadas JSON estructuradas por defecto**: Copia con un solo clic un JSON estandarizado que contiene coordenadas en píxeles, coordenadas normalizadas, dimensiones de la imagen de origen, rutas absolutas locales de archivos e instrucciones de edición opcionales (prompts). Pégalo directamente en tu chat de IA o en el flujo de trabajo de tu agente.
- **Máscara PNG en blanco y negro 1:1 bajo demanda**: Para modelos de inpainting y pipelines tradicionales que requieren máscaras a nivel de píxel, exporta una máscara PNG nítida que coincide con las dimensiones de la imagen original (selección en blanco puro, fondo en negro puro, sin desvanecimiento ni suavizado de bordes).
- **100 % local, sin conexión y privado**: La decodificación de imágenes, el cálculo de coordenadas y la renderización de máscaras se ejecutan íntegramente en tu Mac. Nunca se suben imágenes, rutas de archivo, coordenadas ni prompts. Sin cuentas, sin inicios de sesión, sin anuncios y sin SDK de seguimiento.
- **Enfocado en la delimitación espacial, sin dependencias de IA integradas**: Flash Mask se centra en comunicar con claridad *dónde editar* y *qué cambiar*. La generación y edición real de la imagen las realiza tu herramienta de IA o agente preferido, sin bloqueo de proveedor ni dependencias de la nube.

## Casos de uso

- **Arte de personajes y retoques de generación con IA**: Delimita manos, rasgos faciales, ropa o accesorios para guiar el inpainting específico mientras mantienes estable el resto de la imagen.
- **Limpieza de fotos y eliminación de objetos**: Enmarca rápidamente personas en segundo plano, elementos no deseados, marcas de agua o imperfecciones para que los agentes de edición de imágenes los eliminen y realicen un inpainting limpio.
- **Edición de pósteres y recursos de marketing**: Marca diseños de texto específicos, productos destacados o elementos gráficos que deban reemplazarse en pósteres, banners y recursos para comercio electrónico.
- **Señalización de errores de UI para agentes de programación**: Localiza con precisión errores visuales en capturas de pantalla de UI (como texto cortado, controles superpuestos o desalineaciones de diseño en iOS Simulator, apps de macOS, Canvas, WebGL, mapas, gráficos o UI de juegos) y entrega tanto las coordenadas exactas como las instrucciones de corrección directamente a tu agente de programación.

## Inicio rápido

1. **Abrir una imagen**: Arrastra y suelta una imagen PNG, JPEG/JPG o WebP en la ventana, haz clic en **Abrir imagen** o pega una captura de pantalla desde el portapapeles. Desplázate, haz zoom y alterna entre las vistas **Ajustar** y **Tamaño real** (píxel 1:1).
2. **Delimitar y ajustar regiones**:
   - Haz clic y arrastra sobre la imagen para trazar un área a mano alzada; suelta el botón del ratón para añadirla. Dibuja varias regiones independientes según sea necesario (se combinan automáticamente como una unión).
   - Haz clic en cualquier región existente para ajustarla: arrastra toda la selección para reposicionarla, o arrastra, añade y elimina vértices individuales del polígono.
   - Opcional: Introduce una instrucción para toda la imagen en el campo **«¿Qué quieres que haga tu agente?»**, luego selecciona una región para añadirle una nota.
3. **Copiar JSON o exportar máscara**:
   - Haz clic en **Copiar JSON**: Copia datos estructurados (incluida la ruta local del archivo, dimensiones de la imagen, coordenadas del polígono y el prompt de edición) al portapapeles para pegarlos directamente en tu IA o agente.
   - Haz clic en **Exportar máscara PNG**: Abre la hoja de guardado de macOS para exportar una máscara PNG nítida en blanco y negro que coincide con las dimensiones de la imagen de origen. La máscara marca las áreas seleccionadas; las notas se incluyen en el JSON.

## Formato de datos de coordenadas JSON

Flash Mask genera un JSON versionado y autodescriptivo con sistemas de coordenadas dobles: coordenadas absolutas en píxeles y coordenadas normalizadas `[0.0, 1.0]` (origen en la esquina superior izquierda, X creciente hacia la derecha, Y creciente hacia abajo). La app para Mac utiliza JSON 1.1; la aplicación web del sitio web utiliza JSON 1.0:

```json
{
  "mask_spec_version": "1.1",
  "instruction": "This JSON identifies areas the user selected in the source image. Each polygon marks one selected area; multiple polygons form a combined selection; the first and last points are connected automatically. The top-level `prompt`, if present, applies to the whole image. Each region's `prompt`, if present, applies only to that region. Interpret these texts in the context of the current conversation. The combined geometry marks range only; it does not assign a processing order among regions.",
  "source_image": {
    "file_name": "example.jpg",
    "width": 1920,
    "height": 1080,
    "file_path": "/Users/username/Pictures/example.jpg"
  },
  "coordinate_system": {
    "origin": "top-left",
    "x_direction": "right",
    "y_direction": "down"
  },
  "prompt": "Keep the building",
  "regions": [
    {
      "id": 1,
      "shape": "polygon",
      "points_px": [[96, 108], [480, 108], [480, 432], [96, 432]],
      "points_normalized": [[0.05, 0.1], [0.25, 0.1], [0.25, 0.4], [0.05, 0.4]],
      "prompt": "Remove stray lines"
    },
    {
      "id": 3,
      "shape": "polygon",
      "points_px": [[600, 108], [900, 108], [900, 432], [600, 432]],
      "points_normalized": [[0.3125, 0.1], [0.46875, 0.1], [0.46875, 0.4], [0.3125, 0.4]],
      "prompt": "Use a light gray background"
    }
  ]
}
```

### Referencia de campos

- `mask_spec_version`: Versión de la especificación. La app para Mac genera actualmente `"1.1"`; la aplicación web del sitio web se mantiene en `"1.0"`.
- `instruction`: Guía autodescriptiva integrada que indica a los modelos de IA o agentes receptores cómo interpretar los polígonos y la intención del usuario.
- `source_image`: Nombre del archivo de origen, dimensiones en píxeles (`width`, `height`) y la ruta de archivo local absoluta en el Mac (`file_path` es específico de la app de macOS para que los agentes locales puedan acceder directamente al archivo).
- `coordinate_system`: Definición del sistema de coordenadas (fijado con origen en la esquina superior izquierda, X creciente hacia la derecha, Y creciente hacia abajo).
- `prompt`: Opcional. En el JSON 1.1 para Mac, esta instrucción se aplica a toda la imagen.
- `regions`: Lista de regiones marcadas. Cada región incluye coordenadas enteras en píxeles (`points_px` como `[x, y]`) y coordenadas normalizadas adimensionales (`points_normalized` como `[x/width, y/height]`). El JSON 1.1 de Mac puede incluir un `prompt` opcional para una región específica; los identificadores de región (`id`) se mantienen estables cuando se elimina otra región. Los vértices iniciales y finales se cierran automáticamente, y múltiples regiones forman una unión combinada.

Los consumidores estrictos de JSON 1.0 deben actualizar su validador antes de aceptar JSON 1.1. Flash Mask no descarta notas de región de forma silenciosa.

## Características

- **Amplia compatibilidad de formatos**: Importa imágenes PNG, JPEG/JPG y WebP.
- **Selección multirregión**: Dibuja múltiples selecciones irregulares en una sola imagen; las selecciones se combinan automáticamente en una máscara unificada al exportar.
- **Edición interactiva de vértices**: Arrastra selecciones completas para reposicionarlas, o añade, mueve y elimina vértices de polígonos con precisión.
- **Navegación fluida por el lienzo**: Desplázate y haz zoom con fluidez, con accesos rápidos para alternar entre las vistas **Ajustar** y **Tamaño real** (píxel 1:1).
- **Notas de imagen y de región**: Adjunta una instrucción opcional a toda la imagen y añade notas a regiones individuales en la app para Mac.
- **Sistemas de coordenadas dobles**: Genera tanto coordenadas absolutas en píxeles como coordenadas normalizadas independientes de la resolución para admitir diversos esquemas de modelos y agentes.
- **Fidelidad a la resolución original**: Las máscaras PNG en blanco y negro coinciden 1:1 con las dimensiones de la imagen de origen, renderizadas con selecciones en blanco puro, fondos en negro puro y bordes nítidos sin desvanecimiento.
- **Rutas directas a archivos locales**: La app para macOS genera en el JSON rutas de archivo absolutas verificadas para que los scripts de automatización local y los agentes puedan localizar los archivos al instante.
- **Siete idiomas de interfaz**: Inglés, chino simplificado, chino tradicional, japonés, alemán, francés y español. La app sigue el idioma de tu sistema por defecto; cámbialo en cualquier momento desde el menú de idioma en la barra superior o en Ajustes sin perder la imagen, las regiones ni las notas actuales.
- **Privacidad y funcionamiento local prioritarios**: Se ejecuta 100 % de forma local sin necesidad de iniciar sesión, sin anuncios y sin SDK de seguimiento o análisis.

## Cómo obtener Flash Mask

- **Mac App Store**: Obtén la app oficial precompilada en el [Mac App Store](https://apps.apple.com/es/app/flash-mask/id6803817818?mt=12). Compra única con acceso de por vida, sin suscripciones ni compras dentro de la app.
- **Sitio web oficial**: Visita [flashmask.net](https://flashmask.net/) para obtener detalles y actualizaciones del producto.
- **Versiones del código fuente**: Descarga archivos comprimidos del código fuente desde [GitHub Releases](https://github.com/sudoHG/FlashMask/releases). *(Nota: Las versiones binarias oficiales se distribuyen exclusivamente a través del Mac App Store; GitHub Releases no incluye binarios precompilados).*

## Alcance del código abierto

Este repositorio proporciona el código abierto completo para el cliente de macOS de Flash Mask, que incluye:
- El contenedor anfitrión nativo en AppKit / WKWebView para macOS y el proyecto de Xcode (`macos/`)
- El núcleo del editor integrado en HTML / JavaScript (`index.html`)
- El análisis del protocolo del contrato de coordenadas, la limpieza de vértices de selección y la lógica de generación de máscaras (`src/`)
- Los esquemas de validación del contrato de coordenadas JSON de Flash Mask 1.0 y 1.1 (`schemas/`)
- El conjunto de pruebas unitarias y de validación automatizada de contratos principales (`tests/`)

*Nota: Este repositorio contiene la aplicación independiente para macOS y su núcleo de edición. No incluye scripts de despliegue web independientes ni servicios comerciales de backend (como páginas de aterrizaje de marketing, sistemas de cuotas/publicidad, análisis o infraestructura alojada). Bajo la licencia Apache-2.0, el módulo de edición principal y los contratos de datos compartidos se pueden portar y adaptar libremente.*

## Cómo contribuir

Consulta la [guía de contribución](贡献指南.md) para conocer las comprobaciones locales, la cobertura de CI y los detalles de las solicitudes de extracción (pull requests).

## Compilar la app para Mac desde el código fuente

### Requisitos previos

- Un Mac con una instalación completa de **Xcode**; la versión de macOS del sistema debe ser compatible con esa versión de Xcode
- La app está orientada a **macOS 13.0 o posterior** y se compila como un binario universal (`arm64` + `x86_64`)
- Compilación en Swift puro, AppKit y WebKit: cero dependencias de paquetes externos de Swift

### Comando de compilación

Ejecuta el siguiente comando desde la raíz del repositorio:

```sh
xcodebuild \
  -project 'macos/Flash Mask.xcodeproj' \
  -scheme 'Flash Mask' \
  -configuration Release \
  -derivedDataPath '.derivedData/local' \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO \
  build
```

**Ubicación de salida de la compilación**: `.derivedData/local/Build/Products/Release/Flash Mask.app`

Este comando crea una compilación local sin firmar, compilando el contenedor nativo y empaquetando `index.html` y los recursos de la aplicación en una app independiente. La configuración Release apunta a macOS 13.0 y compila las arquitecturas `arm64` y `x86_64`. La compilación oficial para el App Store se genera mediante el flujo de trabajo independiente de Xcode Archive y distribución, no con este comando de compilación local.

### Script de compilación en un solo comando

Como alternativa, usa el script `build.sh` incluido (ejecuta `./build.sh --help` para más detalles):

```sh
./build.sh
./build.sh --version 1.3.1 --build-number 9 --dmg
```

El script utiliza por defecto la versión `1.3` y la compilación `8`; `--version` y `--build-number` anulan esos valores. Comprueba la versión de la app compilada, la versión mínima de macOS y ambas arquitecturas. `--dmg` empaqueta esa app sin firmar para pruebas locales; el archivo DMG resultante no es apto para distribución con Gatekeeper.

Para la distribución fuera del Mac App Store, firma la app con tu propia identidad de **Developer ID Application** y una marca de tiempo segura, verifica su firma de código, envíala para su notarización, y adjunta y valida el ticket aceptado. Luego empaqueta esa app exacta con:

```sh
./build.sh --package-app "/path/to/stapled/Flash Mask.app"
```

`--package-app` verifica la firma de Developer ID, la marca de tiempo segura, el ticket de notarización, el requisito mínimo de macOS 13.0 y ambas arquitecturas, y luego crea un DMG versionado sin ejecutar `xcodebuild` ni volver a firmar. El propio archivo DMG permanece sin firmar; la firma, notarización y adjunción (staple) de ese contenedor externo son pasos independientes para la distribución directa. El script auxiliar no firma, no notariza, no archiva ni genera una compilación oficial para el App Store. Las compilaciones derivadas deben usar su propio Bundle ID, nombre de aplicación y recursos de marca.

## Ejecución de pruebas principales

Para ejecutar la suite de pruebas del protocolo y la lógica principal se requiere **Node.js 22** o posterior. (*Node.js se utiliza exclusivamente para probar contratos y algoritmos; la compilación de la propia app de macOS no requiere Node.js*).

```sh
npm ci --ignore-scripts
npm test
```

La suite de pruebas cubre:
- Validación de esquemas del contrato de coordenadas JSON para los destinos de macOS y Web
- Restricciones de campos y reglas de omisión específicas de cada plataforma
- Cálculos geométricos de polígonos y simplificación de vértices del lazo (suavizado y eliminación de redundancias)
- Precisión de rasterización de píxeles de máscaras PNG 1:1 en blanco y negro
- Límites de rendimiento y medidas de protección para el recuento de vértices
- Recursos de localización: claves idénticas, marcadores de posición y recursos de paquetes emparejados en los siete idiomas

En macOS, `npm test` también compila y ejecuta las pruebas nativas de Swift (recursos de localización y ubicación de la ventana de Ajustes), que abren brevemente ventanas de prueba. Ejecuta las pruebas de interfaz nativa por separado con `node --test tests/mac-localization-ui.js`. CI ejecuta las pruebas principales en Linux y las pruebas nativas y de interfaz en Apple Silicon macOS 15, Intel y macOS 14; consulta la [guía de contribución](贡献指南.md).

## Estructura del directorio

| Ruta | Descripción |
|---|---|
| `index.html` | Interfaz del editor integrado, interacciones del lienzo y máquina de estados de la UI |
| `src/` | Algoritmos de análisis de contratos de coordenadas, rasterización de máscaras y limpieza de vértices de selección |
| `src/localizations/` | Texto de la interfaz para los siete idiomas, un archivo JSON por idioma |
| `scripts/` | Script en tiempo de compilación que valida y empaqueta los recursos de localización emparejados |
| `schemas/` | Definiciones oficiales de JSON Schema para los contratos de coordenadas de Flash Mask 1.0 y 1.1 |
| `macos/` | Contenedor anfitrión nativo en AppKit / WKWebView, acceso a archivos con ámbito de seguridad y proyecto de Xcode |
| `tests/` | Pruebas unitarias, suites de validación de contratos y fixtures de prueba |

## Licencia y avisos

El código fuente original de Flash Mask está bajo la [Licencia Apache 2.0](LICENSE). Sujeto a los términos de la licencia, puedes usar, modificar y distribuir libremente este software, incluso en obras derivadas comerciales y propietarias.

- Los avisos de derechos de autor y atribución están documentados en [NOTICE](NOTICE).
- Los componentes y dependencias de terceros se enumeran en [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
- Los recursos de marca —incluidos el nombre «Flash Mask», los logotipos y los iconos de la aplicación— están protegidos bajo los [Términos de recursos de marca](BRAND_ASSETS.md) independientes y quedan excluidos de la concesión de la licencia Apache-2.0.
- **Propiedad de los datos del usuario**: Todos los datos de coordenadas JSON, imágenes y máscaras PNG generadas con Flash Mask pertenecen en su totalidad al usuario y no están sujetos a la licencia Apache-2.0.
