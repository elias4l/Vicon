#include "fuentevideo.h"
#include <chrono> // Tiemout de recpcion de un frame.
#include <utility> // Para usar std::move() y mover el vector del frame en vez de copiarlo.

FuenteVideo::~FuenteVideo() // Destructor.
{
    desconectar(); // Detener el bucle de recepcion de frames y cerrar el hilo si esta activo.
}

bool FuenteVideo::conectar(int indiceDispositivo)
{
    FT_STATUS ftStatus = FT_Open(indiceDispositivo, &ftHandle); // Abrir el dispositivo FTDI segun el indice.
    if (ftStatus != FT_OK)
    {
        ftHandle = nullptr;
        return false;
    }

    ftStatus = FT_SetTimeouts(ftHandle, 1000, 1000); // Setear los timeours de lectura y escritura en 1 segundo.

    if (ftStatus == FT_OK)
    {
        ftStatus = FT_SetUSBParameters(ftHandle, 65536, 65536); // Setear el tamano de los buffers de lectura y escritura a 65536 bytes.
    }

    if (ftStatus == FT_OK)
    {
        ftStatus = FT_SetLatencyTimer(ftHandle, 4); // Setear la latencia maxima a 4 ms.
    }

    if (ftStatus == FT_OK)
    {
        ftStatus = FT_Purge(ftHandle, FT_PURGE_RX | FT_PURGE_TX); // Limpiar los buffers de lectura y escritura.
    }

    if (ftStatus != FT_OK) // Si algo falla, cerrar dispositivo y devolver false.
    {
        FT_Close(ftHandle);
        ftHandle = nullptr;
        return false;
    }

    return true;
}

void FuenteVideo::desconectar()
{
    detenerRecepcion(); // Detener el bucle de recepcion de frames y cerrar el hilo si esta activo.
    if (ftHandle != nullptr)
    {
        FT_Close(ftHandle);
        ftHandle = nullptr;
    }
}

bool FuenteVideo::estaConectado() const
{
    return ftHandle != nullptr;
}

bool FuenteVideo::recibirFrame(bool color, std::vector<unsigned char>& frame) // Realiza la rececpcion de un frame.
{
    if(ftHandle == nullptr)
    {
        return false; // No hay dispositivo conectado.
    }

    const unsigned char CMD_LEER_FRAME = 0x01; // BIT0 indica transmitir un frame.
    const unsigned char CMD_COLOR = 0x02; // BIT1 indica color (1) o BN (0).
    const DWORD frameBytes = color ? 640u * 480u * 2u : 640u * 480u; // Tamano del frame en bytes, para color 614400 bytes, para BN 307200 bytes.

    frame.resize(frameBytes); // Redimensionar el vector de bytes del frame en caso de que se haya cambiado el modo de color.
    FT_STATUS ftStatus = FT_Purge(ftHandle, FT_PURGE_RX | FT_PURGE_TX); // Limpiar los buffers de lectura y escritura.
    if (ftStatus != FT_OK)
    {
        return false;
    }

    unsigned char comando = CMD_LEER_FRAME; // La FPGA comprueba el BIT0 para decidir si debe escribir un frame.
    if (color)
    {
        comando |= CMD_COLOR; // La FPGA comprueba el BIT1 para decidir si el frame es a color.
    }

    DWORD bytesEscritos = 0;
    ftStatus = FT_Write(ftHandle, &comando, 1, &bytesEscritos); // Enviar el comando de lectura de un frame a la FPGA.
    if (ftStatus != FT_OK || bytesEscritos != 1)
    {
        return false;
    }

    DWORD bytesLeidosTotales = 0;
    auto tiempoInicio = std::chrono::steady_clock::now(); // Tiempo de inicio para el timeout de lectura del frame.

    while (bytesLeidosTotales < frameBytes)
    {
        DWORD bytesLeidos = 0; // En cada llamada a FT_Read().
        DWORD bytesPorLeer = frameBytes - bytesLeidosTotales;
        if (bytesPorLeer > 65536) // Numero de bytes a leer. Maximo 65536.
        {
            bytesPorLeer = 65536;
        }

        ftStatus = FT_Read(ftHandle, &frame[bytesLeidosTotales], bytesPorLeer, &bytesLeidos); // Leer los bytes del frame desde el dispositivo FTDI.
        if (ftStatus != FT_OK)
        {
            return false;
        }

        bytesLeidosTotales += bytesLeidos;

        // Comprobar si ha pasado el tiempo de timeout de 1 segundo.
        auto tiempoActual = std::chrono::steady_clock::now();
        auto duracion = std::chrono::duration_cast<std::chrono::milliseconds>(tiempoActual - tiempoInicio);
        if (duracion.count() > 1000)
        {
            return false; // Timeout de lectura del frame.
        }
    }

    return true;
}

void FuenteVideo::iniciarRecepcion(bool color) // Inicia la recepcion de frames en un hilo separado.
{
    if (!estaConectado() || recepcionActiva)
    {
        return; // No hay dispositivo conectado o ya se esta recibiendo.
    }
    // Cerrar hilo de recepcion anterior si estaba activo.
    if (hiloRecepcion.joinable())
    {
        hiloRecepcion.join(); // Esperar a que el hilo termine.
    }
    recepcionActiva = true;
    hiloRecepcion = std::thread(&FuenteVideo::bucleRecepcion, this, color); // Iniciar el hilo de recepcion de frames en bucleRecepcion().
}

void FuenteVideo::bucleRecepcion(bool color) // Metodo privado, solicita frames de forma continuada mientras recepcionActiva sea true y no haya fallos.
{
    while (recepcionActiva)
    {
        std::vector<unsigned char> frame;
        if (!recibirFrame(color, frame))
        {
            recepcionActiva = false; // Error al recibir el frame, se detiene la recepcion.
            break;
        }

        // Bloquear el acceso al ultimo frame mientras se copia, y marcar que hay un frame nuevo.
        {
            std::lock_guard<std::mutex> lock(mutexCola);
            if (colaFrames.size() > MAX_FRAMES_COLA)
            {
                colaFrames.pop_front(); // Eliminar el frame mas antiguo.
            }
            colaFrames.push_back(std::move(frame)); // Guardar el ultimo frame recibido.
        }
    }
}

void FuenteVideo::detenerRecepcion() // Detiene la recepcion de frames y espera a que el hilo termine.
{
    recepcionActiva = false;
    if (hiloRecepcion.joinable())
    {
        hiloRecepcion.join(); // Esperar a que el hilo termine.
    }
    // Limpiar los frames recibidos en caso de que se cambie de color.
    {
        std::lock_guard<std::mutex> lock(mutexCola);
        colaFrames.clear();
    }

}

bool FuenteVideo::obtenerUltimoFrame(std::vector<unsigned char>& frame) // Copia el ultimo frame recibido en el vector frame.
{
    std::lock_guard<std::mutex> lock(mutexCola); // Bloquear el acceso a la cola de frames mientras se copia.
    if (colaFrames.empty())
    {
        return false; // No hay frame nuevo disponible.
    }
    frame = std::move(colaFrames.back()); // Obtener frame mas reciente y limpiar.
    colaFrames.clear();
    return true;
}

bool FuenteVideo::estaRecibiendo() const // Para detectar en MainWindow si el hilo de recepcion esta activo o se detuvo por algun error.
{
    return recepcionActiva;
}
