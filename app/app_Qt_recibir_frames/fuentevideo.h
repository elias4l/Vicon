#pragma once

#include "ftd2xx.h" // Libreria con la api oficial de FTDI.
#include <vector> // Arrays dinamicos para trabajar con frames.
#include <thread>
#include <atomic> // Usado en los flags, al ser compartidos entre los hilos.
#include <mutex> // Semaforos de exclusion mutua.
#include <deque> // Cola para almacenar los frames recibidos en un buffer de varios frames.

class FuenteVideo
{
public:
    FuenteVideo() = default; // Constructor.
    ~FuenteVideo(); // Destructor.
    bool enviarComando(unsigned char comando); // Envia cualquier comando. Usado para enviar reset.
    bool conectarFTDI(int indiceDispositivo); // Conecta y configura la conexion con el dispositivo FTDI.
    void desconectarFTDI(); // Detiene la captura de frames y desconecta al dispostivo FTDI.
    bool dispFTDIConectado() const; // Funcion de consulta para saber si el dispositivo esta conectado (handler != nullptr).
    void iniciarHiloFuenteVideo(bool color); // Lanza el hilo para recibir frames de forma continua.
    void detenerHiloFuenteVideo(); // Detiene y cierra el hilo.
    bool obtenerUltimoFrame(std::vector<unsigned char>& frame); // Extrae de la cola el frame mas reciente.
    bool recepcionActiva() const; // Consulta desde MainWindow si el hilo de captura sigue activo.

private:
    const size_t MAX_FRAMES_COLA = 3; // Limite de frames en la cola.
    FT_HANDLE ftHandle = nullptr; // Puntero del handler del dispositivo FTDI.
    int indiceDispositivo = -1; // El sistema intenta reconfigurarse ante algun error.
    
    std::thread hiloFuenteVideo;
    std::atomic<bool> flagFuenteVideoActivo{ false }; // Flag del bucle de recepcion de frames. Atomico al compartirse entre hilos.

    std::deque<std::vector<unsigned char>> colaFrames; // Cola FIFO de los frames recibidos aun sin mostrar.
    std::mutex mutexColaFrames; // Mutex para proteger y sincronizar el acceso a la cola de frames entre los hilos.
    
    bool recibirFrame(bool color, std::vector<unsigned char>& frame); // Recibe un frame desde el dispositivo FTDI.
    void bucleRecepcion(bool color); // Funcion principal del hilo.

};
