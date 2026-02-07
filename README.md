2# Rocky Offline SDK

![Logo](assets/images/imagenInicio.png)

## Descripción

Rocky Offline SDK es una aplicación móvil desarrollada en Flutter que permite a instituciones prestadoras de servicios de salud (IPS) gestionar información de pacientes de manera offline. Esta solución facilita el acceso a datos críticos de pacientes sin necesidad de una conexión constante a internet, ideal para entornos con conectividad limitada o intermitente.

## Características Principales

- **Registro y validación de dispositivos**: Sistema seguro de autenticación para dispositivos autorizados
- **Gestión de bases de datos offline**: Importación y exportación de datos desde archivos CSV
- **Búsqueda rápida de pacientes**: Consulta eficiente por número de identificación
- **Impresión Bluetooth**: Conectividad con impresoras térmicas para imprimir información de pacientes
- **Interfaz adaptable**: Diseñada para funcionar en diferentes tamaños de pantalla
- **Sincronización de datos**: Actualización de información cuando hay conexión disponible

## Requisitos del Sistema

- Flutter SDK: ^3.5.4
- Dispositivos Android: Android 5.0 (API level 21) o superior
- iOS: iOS 11.0 o superior

## Dependencias Principales

- **file_picker**: ^10.2.0 - Para selección de archivos CSV
- **sqflite**: ^2.3.2+1 - Base de datos local
- **blue_thermal_printer**: ^1.2.3 - Conectividad con impresoras Bluetooth
- **permission_handler**: ^12.0.1 - Gestión de permisos del sistema
- **shared_preferences**: ^2.5.3 - Almacenamiento de configuraciones
- **device_info_plus**: ^11.3.0 - Información del dispositivo para registro
- **http**: ^1.5.0 - Comunicación con servidores para validación

## Instalación

1. Clone el repositorio:
   ```
   git clone https://github.com/tuorganizacion/rocky_offline_sdk.git
   ```

2. Navegue al directorio del proyecto:
   ```
   cd rocky_offline_sdk
   ```

3. Instale las dependencias:
   ```
   flutter pub get
   ```

4. Ejecute la aplicación:
   ```
   flutter run
   ```

## Ejecución Local

### Requisitos Previos

1. **Instalar Flutter SDK**:
   - Descargue Flutter desde [flutter.dev](https://flutter.dev/docs/get-started/install)
   - Agregue Flutter a su PATH
   - Ejecute `flutter doctor` para verificar que la instalación esté completa

2. **Configurar un IDE**:
   - Instale [Visual Studio Code](https://code.visualstudio.com/) o [Android Studio](https://developer.android.com/studio)
   - Instale las extensiones de Flutter y Dart para su IDE

3. **Configurar dispositivos**:
   - **Para Android**:
     - Instale [Android Studio](https://developer.android.com/studio) y configure un emulador desde AVD Manager
     - O conecte un dispositivo físico en modo desarrollador con depuración USB activada
   - **Para iOS** (requiere macOS):
     - Instale [Xcode](https://developer.apple.com/xcode/)
     - Configure un simulador o conecte un dispositivo físico

### Pasos para Ejecutar

1. **Prepare el ambiente de desarrollo**:
   ```bash
   # Verifique que todo esté configurado correctamente
   flutter doctor
   ```

2. **Ejecute la aplicación en modo desarrollo**:
   ```bash
   # Para ejecutar en el dispositivo/emulador conectado
   flutter run
   
   # Para especificar un dispositivo cuando hay varios conectados
   flutter run -d <ID-DEL-DISPOSITIVO>
   
   # Para obtener una lista de dispositivos disponibles
   flutter devices
   ```

3. **Opciones durante la ejecución**:
   - Presione `r` en la terminal para hacer un hot reload (actualizar cambios sin reiniciar)
   - Presione `R` para hacer un hot restart (reinicio completo de la app)
   - Presione `q` para salir

4. **Modos de compilación**:
   ```bash
   # Modo debug (desarrollo)
   flutter run

   # Modo release (producción)
   flutter run --release

   # Modo profile (análisis de rendimiento)
   flutter run --profile
   ```

### Solución de Problemas Comunes

- **Error de conexión al dispositivo**: Verifique que el dispositivo esté conectado y sea reconocido con `flutter devices`
- **Errores de dependencias**: Ejecute `flutter clean` seguido de `flutter pub get`
- **Problemas con permisos**: Asegúrese de que los permisos necesarios estén correctamente configurados en `AndroidManifest.xml` para Android o `Info.plist` para iOS
- **Problemas con Bluetooth**: Verifique que tenga los permisos adecuados y que el dispositivo soporte los protocolos Bluetooth necesarios

### Generación de APK/IPA para Distribución

- **Para Android (APK)**:
  ```bash
  # Generar APK release
  flutter build apk
  
  # Generar APK por arquitectura para reducir tamaño
  flutter build apk --split-per-abi
  
  # La ubicación del APK generado será mostrada al final del comando
  ```

- **Para iOS (requiere macOS)**:
  ```bash
  # Generar archivo IPA
  flutter build ios
  
  # Luego abra el proyecto en Xcode para distribuir a través de App Store Connect
  open ios/Runner.xcworkspace
  ```

## Estructura del Proyecto

```
lib/
├── main.dart                    # Punto de entrada de la aplicación
├── screens/                     # Pantallas de la aplicación
│   ├── auth/                    # Autenticación y registro de dispositivos
│   ├── home/                    # Pantalla principal y gestión de base de datos
│   └── patients/                # Búsqueda y detalles de pacientes
├── services/                    # Servicios de la aplicación
│   ├── auth_service.dart        # Autenticación y validación
│   ├── database_service.dart    # Gestión de base de datos
│   └── expiration_service.dart  # Control de licencias
└── utils/                       # Utilidades y helpers
    └── csv_helper.dart          # Manejo de archivos CSV
```

## Flujo de Trabajo

### 1. Registro y Validación de Dispositivos

#### Registro Inicial
- Al iniciar la aplicación por primera vez, se presenta la pantalla de registro de dispositivo
- El usuario debe ingresar un código IPS válido proporcionado por ROCKY S.A.S
- La aplicación captura información del dispositivo (ID único, modelo, sistema operativo)
- Se envía la información al servidor central para validación

#### Proceso de Validación
- El servidor verifica que el código IPS corresponda a una institución activa
- Se genera una clave de validación única para el dispositivo
- La aplicación almacena localmente las credenciales de autenticación
- Se establece una fecha de expiración para la licencia

#### Renovación de Licencia
- La aplicación verifica la validez de la licencia en cada inicio
- Cuando se acerca la fecha de expiración, se muestra una notificación al usuario
- El proceso de renovación requiere conexión a internet para contactar al servidor
- Se puede renovar automáticamente si la institución mantiene su suscripción activa

### 2. Gestión de Base de Datos

#### Importación Inicial
- Desde la pantalla principal, el usuario selecciona "Cargar Base de Datos"
- Se abre un selector de archivos para elegir el CSV con la información de pacientes
- La aplicación valida el formato y estructura del archivo
- Se muestra un indicador de progreso durante la carga

#### Estructura del CSV
El archivo CSV debe contener las siguientes columnas:
- **NumeroId**: Número de identificación único del paciente
- **TipoIdentificacion**: Tipo de documento (CC, TI, etc.)
- **Nombres**: Nombre completo del paciente
- **FechaNto**: Fecha de nacimiento (formato YYYY-MM-DD)
- **Sexo**: Género del paciente (M/F)
- **EdadAnos**: Edad actual en años
- **CursoVida**: Etapa de vida del paciente
- **ActividadesPendientes**: Actividades médicas pendientes
- **LaboratoriosPendientes**: Exámenes de laboratorio pendientes

#### Actualización de Datos
- El usuario puede actualizar la base de datos cargando un nuevo archivo CSV
- La aplicación compara los registros para identificar cambios
- Se muestra un resumen de los cambios detectados antes de confirmar
- El historial de actualizaciones se mantiene para auditoría

### 3. Búsqueda y Gestión de Pacientes

#### Proceso de Búsqueda
- En la pantalla principal, el usuario selecciona "Buscar Paciente"
- Ingresa el número de identificación del paciente
- La aplicación busca en la base de datos local
- Los resultados se muestran instantáneamente sin necesidad de internet

#### Visualización de Información
- Al encontrar un paciente, se muestra su información detallada:
  - Datos personales (nombre, edad, tipo de identificación)
  - Actividades pendientes según la Resolución 3280
  - Laboratorios pendientes
  - Curso de vida y recomendaciones específicas

#### Impresión de Información
- En la pantalla de detalles, se ofrece la opción de imprimir
- El sistema busca impresoras Bluetooth disponibles
- El usuario selecciona la impresora deseada
- Se genera un formato estandarizado con los datos relevantes
- La impresión marca automáticamente al paciente como atendido

### 4. Ciclo de Uso Diario

#### Inicio de Jornada
1. El personal de salud inicia la aplicación
2. El sistema verifica la validez de la licencia
3. Se carga automáticamente la última base de datos utilizada
4. La aplicación está lista para buscar pacientes

#### Durante la Atención
1. Se busca al paciente por número de identificación
2. Se consulta la información relevante para la atención
3. Se imprime la información si es necesario
4. Se continúa con el siguiente paciente

#### Fin de Jornada
1. Los datos de pacientes atendidos se almacenan localmente
2. Si hay conexión a internet disponible, se pueden sincronizar los datos de atención
3. La aplicación conserva el estado para el siguiente uso

## Seguridad

La aplicación implementa varias capas de seguridad:
- Validación de dispositivos contra un servidor central
- Sistema de licencias con fecha de expiración
- Encriptación de datos sensibles
- Validación de integridad de la base de datos

## Licencia

Todos los derechos reservados © ROCKY S.A.S 2025

## Contacto

Para soporte técnico o consultas, contactar a:
- Email: soporte@rocky.com

---
