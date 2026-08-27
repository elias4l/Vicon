#include "fuentevideo.h"
#include <chrono> // Usado en el timeout de lectura de un frame.
#include <utility> // Usado en std::move() para mover y no copiar el frame.
#include <fstream> // Usados para trabajar con los logs (ofstream()).
#include <iomanip> // Usado para formatear la fecha (put_time()).
#include <string>
#include <ctime>
#include <Windows.h>

std::mutex mutexLogs;
std::wstring rutaArchivoLogs;

void escribirLog(const std::string& mensaje) // Crea fichero de logs desde la ultima conexion si no existe, y escribir el mensaje al final del archivo.
{
    std::lock_guard<std::mutex> lock(mutexLogs); // un acceso simultaneo al archivo de logs.
    auto fecha_hora = std::chrono::system_clock::now();
    std::time_t fecha_hora_t = std::chrono::system_clock::to_time_t(fecha_hora); // Formato estandar time_t.
    std::tm fecha_hora_local; // Formato estandar local.
    localtime_s(&fecha_hora_local, &fecha_hora_t);
    if (rutaArchivoLogs.empty()) // No se ha creado desde la ultima conexion del dispositivo FTDI.
    {
        wchar_t ruta[MAX_PATH]; // Ruta para la localizacion del archivo de logs.
        GetModuleFileNameW(nullptr, ruta, MAX_PATH); // Ejecutable actual.
        std::wstring rutaString(ruta); // Formato estandar wstring.
        rutaString = rutaString.substr(0, rutaString.find_last_of(L"\\/")); // Usar solo el directorio.
        wchar_t nombreArchivo[64];
        wcsftime(nombreArchivo, 64, L"registro_%Y-%m-%d_%H-%M-%S.log", &fecha_hora_local); // Crea archivo de log con la fecha y hora actual, en la ubicacion del ejecutable.
        rutaArchivoLogs = rutaString + L"\\" + nombreArchivo; // Nombre y ruta completo al archivo.
    }
    std::ofstream archivoLogs(rutaArchivoLogs, std::ios::app); // Abrir archivo creado.
    if (archivoLogs.is_open())
    {
        archivoLogs << std::put_time(&fecha_hora_local, "%Y-%m-%d %H:%M:%S    ") << mensaje << std::endl; // Anadir mensaje al final.
    }
}

void vaciarRutaLog() // Vaciar la ruta del ultimo archivo de logs usado.
{
    std::lock_guard<std::mutex> lock(mutexLogs);
    rutaArchivoLogs.clear();
}

FuenteVideo::~FuenteVideo() // Destructor.
{
    desconectarFTDI(); // Detiene el bucle de recepcion de frames, cierra el hilo y desconecta el dispositivo FTDI.
}

bool FuenteVideo::enviarComando(unsigned char comando) // Envia comando pasado por parametroal dispositivo FTDI.
{
    if (ftHandle == nullptr)
    {
        return false;
    }

    DWORD bytesEscritos = 0;
    FT_STATUS ftStatus = FT_Write(ftHandle, &comando, 1, &bytesEscritos);
    if (ftStatus != FT_OK || bytesEscritos != 1)
    {
        escribirLog("Error de escritura FTDI: " + std::to_string(ftStatus));
    }
    if (comando == 0x80)
    {
        escribirLog(ftStatus == FT_OK && bytesEscritos == 1 ? "Comando de reset enviado" : "Error al enviar el comando de reset");
    }
    return ftStatus == FT_OK && bytesEscritos == 1;
}

bool FuenteVideo::conectarFTDI(int indiceDispositivo)
{
    this->indiceDispositivo = indiceDispositivo;
    FT_STATUS ftStatus = FT_Open(indiceDispositivo, &ftHandle); // Abrir el dispositivo FTDI segun el indice.
    if (ftStatus != FT_OK)
    {
        escribirLog("Error al conectar FTDI: " + std::to_string(ftStatus));
        ftHandle = nullptr;
        return false; // Aborta si no se puede abrir.
    }

    ftStatus = FT_SetTimeouts(ftHandle, 1000, 1000); // Setear los timeouts de lectura y escritura por USB en 1 segundo.
    if (ftStatus == FT_OK)
    {
        ftStatus = FT_SetUSBParameters(ftHandle, 65536, 65536); // Setear el tamano de los buffers de lectura y escritura del driver a 65536 bytes (64KB).
    }

    if (ftStatus == FT_OK)
    {
        ftStatus = FT_SetLatencyTimer(ftHandle, 1); // Setear la latencia maxima a 1 ms.
    }

    if (ftStatus == FT_OK)
    {
        ftStatus = FT_Purge(ftHandle, FT_PURGE_RX | FT_PURGE_TX); // Limpiar los buffers de lectura y escritura.
        escribirLog("Resultado de purga FTDI: " + std::to_string(ftStatus));
    }

    if (ftStatus != FT_OK) // Si algo falla, cerrar dispositivo y devolver false.
    {
        escribirLog("Error de configuracion FTDI: " + std::to_string(ftStatus));
        FT_Close(ftHandle);
        ftHandle = nullptr;
        return false;
    }

    escribirLog("Conexion FTDI");
    return true;
}

void FuenteVideo::desconectarFTDI()
{
    detenerHiloFuenteVideo(); // Detener el bucle de recepcion de frames y cerrar el hilo si esta activo.
    if (ftHandle != nullptr)
    {
        escribirLog("Desconexion manual completa");
        FT_Close(ftHandle); // Cerrar la conexion con el dispostitvo FTDI.
        ftHandle = nullptr;
        vaciarRutaLog();
    }
}

bool FuenteVideo::dispFTDIConectado() const // Funcion para comprobar que hay un handler FTDI configurado.
{
    return ftHandle != nullptr;
}

bool FuenteVideo::recibirFrame(bool color, std::vector<unsigned char>& frame) // Realiza la rececpcion de un frame, que sera usada en bucleRecepcion().
{
    if(ftHandle == nullptr)
    {
        escribirLog("Error FTDI: dispositivo no conectado");
        return false; // No hay dispositivo conectado.
    }

    const unsigned char CMD_LEER_FRAME = 0x01; // BIT0 le indica a la FPGA transmitir un frame.
    const unsigned char CMD_COLOR = 0x02; // BIT1 indica color (1) o BN (0).
    const DWORD frameBytes = color ? 640u * 480u * 2u : 640u * 480u; // Tamano del frame en bytes, para color 614400 bytes, para BN 307200 bytes.

    frame.resize(frameBytes); // Redimensionar el vector de bytes del frame segun el color seleccionado.
    FT_STATUS ftStatus;

    unsigned char comando = CMD_LEER_FRAME; // La FPGA comprueba el BIT0 para decidir si debe escribir un frame.
    if (color)
    {
        comando |= CMD_COLOR; // Or a nivel de bit. La FPGA comprueba el BIT1 para decidir si el frame es a color.
    }

    DWORD bytesEscritos = 0;
    ftStatus = FT_Write(ftHandle, &comando, 1, &bytesEscritos); // Transmitir el comando de lectura de un frame a la FPGA.
    if (ftStatus != FT_OK || bytesEscritos != 1)
    {
        escribirLog("Error de escritura FTDI: " + std::to_string(ftStatus));
        return false;
    }

    DWORD bytesLeidosTotales = 0;
    auto tiempoInicio = std::chrono::steady_clock::now(); // Tiempo de inicio para el timeout de lectura del frame.

    while (bytesLeidosTotales < frameBytes)
    {
        DWORD bytesLeidos = 0; // En cada llamada a FT_Read().
        DWORD bytesPorLeer = frameBytes - bytesLeidosTotales;
        if (bytesPorLeer > 65536) // Numero de bytes a leer. Maximo del buffer del driver 65536.
        {
            bytesPorLeer = 65536;
        }

        ftStatus = FT_Read(ftHandle, &frame[bytesLeidosTotales], bytesPorLeer, &bytesLeidos); // Leer los bytes del frame desde el dispositivo FTDI directamente en el vector del parametro.
        if (ftStatus != FT_OK)
        {
            escribirLog("Error de lectura FTDI: " + std::to_string(ftStatus));
            return false;
        }

        bytesLeidosTotales += bytesLeidos;

        // Comprobar si ha pasado el tiempo de timeout de 1 segundo.
        auto tiempoActual = std::chrono::steady_clock::now();
        auto duracion = std::chrono::duration_cast<std::chrono::milliseconds>(tiempoActual - tiempoInicio);
        if (duracion.count() > 1000)
        {
            escribirLog("Timeout de recepcion");
            frame.clear();
            return false; // Timeout de lectura de un frame. Debe de haber ocurrido un error.
        }
    }
    return true; // Fotograma almacenado correctamente en el parametro frame.
}

void FuenteVideo::iniciarHiloFuenteVideo(bool color) // Inicia la recepcion de frames en un hilo separado.
{
    if (!dispFTDIConectado() || flagRecepcionActiva)
    {
        return; // No hay dispositivo conectado o ya el hilo ya esta activo.
    }
    // Cerrar hilo de recepcion anterior si estaba activo.
    if (hiloFuenteVideo.joinable())
    {
        hiloFuenteVideo.join(); // Esperar a que el hilo termine.
    }
    flagRecepcionActiva = true;
    hiloFuenteVideo = std::thread(&FuenteVideo::bucleRecepcion, this, color); // Iniciar el hilo de recepcion de frames con bucleRecepcion().
}

void FuenteVideo::bucleRecepcion(bool color) // Metodo principal. Bucle que solicita frames de forma continuada mientras recepcionActiva sea true y no haya fallos.
{
    int intentosRecuperacion = 0; // En caso de fallo, intenta reconfigurarse tres veces antes de lanzar error.
    escribirLog("Inicio de la recepcion de frames (bucleRecepcion()).");
    while (flagRecepcionActiva) // Flag que mantiene el bucle activo.
    {
        std::vector<unsigned char> frame; // Guarda los bytes del frame obtenido desde el dispositivo FTDI.
        if (!recibirFrame(color, frame)) // Error o no hay frame disponible.
        {
            if (!flagRecepcionActiva) // recibirFrame detenido voluntariamente. Salir del bucle.
            {
                break;
            }
            if (intentosRecuperacion >= 3) // Se han producido tres errores de conexion, salir.
            {
                escribirLog("Error definitivo despues de tres intentos de recuperacion.");
                escribirLog("Saliendo de la recepcion.");
                if (ftHandle != nullptr) // Cerrar dispositivo FTDI.
                {
                    FT_Close(ftHandle);
                    ftHandle = nullptr;
                }
                vaciarRutaLog(); // Cerrar acceso al archivo log.
                flagRecepcionActiva = false; // Se detiene la recepcion.
                return;
            }
            intentosRecuperacion++; // Error de conexion, se intenta reconectar: cerrar dispositivo FTDI, conectar de nuevo, resetear FPGA, esperar 3 segundos.
            escribirLog("Intento de recuperacion " + std::to_string(intentosRecuperacion));

            if (ftHandle != nullptr) // Cerrar dispositivo FTDI.
            {
                FT_Close(ftHandle);
                ftHandle = nullptr;
                escribirLog("Cierre temporal del handle FTDI.");
            }
            bool conectado = conectarFTDI(indiceDispositivo);
            escribirLog(conectado ? "Resultado de reconexion FTDI: correcto." : "Resultado de reconexion FTDI: error.");
            if (conectado)
            {
                enviarComando(0x80);
            }
            std::this_thread::sleep_for(std::chrono::seconds(3));
            if (!flagRecepcionActiva)
            {
                break;
            }
            continue;
        }
        // No hay error en esta iteracion.
        if (intentosRecuperacion > 0)
        {
            escribirLog("Recepcion recuperada.");
            intentosRecuperacion = 0;
        }
        // Bloquear el acceso al ultimo frame mientras se copia, y marcar que hay un frame nuevo.
        {
            std::lock_guard<std::mutex> lock(mutexColaFrames);
            if (colaFrames.size() >= MAX_FRAMES_COLA) // En caso de llenarse el buffer de frames.
            {
                colaFrames.pop_front(); // Eliminar el frame mas antiguo.
            }
            colaFrames.push_back(std::move(frame)); // Guardar el ultimo frame recibido. std::move evita tener que copiar de nuevo.
        } // Lock termina.
    }
    escribirLog("Final de la recepcion");
}

void FuenteVideo::detenerHiloFuenteVideo() // Detiene la recepcion de frames y espera a que el hilo termine.
{
    flagRecepcionActiva = false; // Detiene el bucle en bucleRecepcion().
    if (hiloFuenteVideo.joinable())
    {
        hiloFuenteVideo.join(); // Esperar a que el hilo termine.
    }
    // Limpiar los frames pendientes.
    {
        std::lock_guard<std::mutex> lock(mutexColaFrames);
        colaFrames.clear();
    }

}

bool FuenteVideo::obtenerUltimoFrame(std::vector<unsigned char>& frame) // Copia el ultimo frame recibido en el vector frame. Funcion que usa MainWindow para tomar el frame.
{
    std::lock_guard<std::mutex> lock(mutexColaFrames); // Bloquear el acceso a la cola mientras se copia.
    if (colaFrames.empty())
    {
        return false; // No hay frames en la cola.
    }
    frame = std::move(colaFrames.back()); // Obtener frame mas reciente y limpiar.
    colaFrames.clear(); // Descartar frames existentes para mejorar la latencia.
    return true;
}

bool FuenteVideo::recepcionActiva() const // Para detectar en MainWindow si el hilo de recepcion esta activo o se detuvo por algun error.
{
    return flagRecepcionActiva;
}
