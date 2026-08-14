/// Modos de captura soportados por la aplicación.
enum ScannerMode {
  /// ARCore (Android) / ARKit (iOS)
  ar,

  /// Cámara + sensores (giroscopio/acelerómetro) sin AR nativo.
  basic,

  /// Dibujo manual 2D sobre pantalla táctil.
  manual,

  /// Importación desde archivo JSON.
  imported,
}
