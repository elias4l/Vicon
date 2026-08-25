#include "fuentevideo.h"
#include <chrono> // Usado en el timeout de lectura de un frame.
#include <utility> // Usado en std::move() para mover y no copiar el frame.

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
    return ftStatus == FT_OK && bytesEscritos == 1;
}

bool FuenteVideo::conectarFTDI(int indiceDispositivo)
{
    FT_STATUS ftStatus = FT_Open(indiceDispositivo, &ftHandle); // Abrir el dispositivo FTDI segun el indice.
    if (ftStatus != FT_OK)
    {
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
    }

    if (ftStatus != FT_OK) // Si algo falla, cerrar dispositivo y devolver false.
    {
        FT_Close(ftHandle);
        ftHandle = nullptr;
        return false;
    }

    return true;
}

void FuenteVideo::desconectarFTDI()
{
    detenerHiloFuenteVideo(); // Detener el bucle de recepcion de frames y cerrar el hilo si esta activo.
    if (ftHandle != nullptr)
    {
        FT_Close(ftHandle); // Cerrar la conexion con el dispostitvo FTDI.
        ftHandle = nullptr;
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
            return false;
        }

        bytesLeidosTotales += bytesLeidos;

        // Comprobar si ha pasado el tiempo de timeout de 1 segundo.
        auto tiempoActual = std::chrono::steady_clock::now();
        auto duracion = std::chrono::duration_cast<std::chrono::milliseconds>(tiempoActual - tiempoInicio);
        if (duracion.count() > 1000)
        {
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
    while (flagRecepcionActiva) // Flag que mantiene el bucle activo.
    {
        std::vector<unsigned char> frame;
        if (!recibirFrame(color, frame))
        {
            flagRecepcionActiva = false; // Error al recibir el frame, se detiene la recepcion.
            break;
        }

        // Bloquear el acceso al ultimo frame mientras se copia, y marcar que hay un frame nuevo.
        {
            std::lock_guard<std::mutex> lock(mutexColaFrames);
            if (colaFrames.size() > MAX_FRAMES_COLA) // En caso de llenarse el buffer de frames.
            {
                colaFrames.pop_front(); // Eliminar el frame mas antiguo.
            }
            colaFrames.push_back(std::move(frame)); // Guardar el ultimo frame recibido. std::move evita tener que copiar.
        } // Lock termina.
    }
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
