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
    bool conectarFTDI(int indiceDispositivo); // Conecta y configura la conexion con el dispositivo FTDI.
    void desconectarFTDI(); // Detiene la captura de frames y desconecta al dispostivo FTDI.
    bool dispFTDIConectado() const; // Funcion de consulta para saber si el dispositivo esta conectado (handler != nullptr).
    void iniciarHiloRecepcionFrames(bool color); // Lanza el hilo para recibir frames de forma continua.
    void detenerHiloRecepcionFrames(); // Detiene y cierra el hilo.
    bool obtenerUltimoFrame(std::vector<unsigned char>& frame); // Extrae de la cola el frame mas reciente.
    bool recepcionActiva() const; // Consulta desde MainWindow si el hilo de captura sigue activo.

private:
    FT_HANDLE ftHandle = nullptr; // Puntero del handler del dispositivo FTDI.
    
    std::thread hiloFuenteVideo;
    std::atomic<bool> flagRecepcionActiva{ false }; // Flag del bucle de recepcion de frames. Atomico al compartirse entre hilos.

    std::deque<std::vector<unsigned char>> colaFrames; // Cola FIFO de los frames recibidos aun sin mostrar.
    std::mutex mutexColaFrames; // Mutex para proteger y sincronizar el acceso a la cola de frames entre los hilos.
    const size_t MAX_FRAMES_COLA = 3; // Limite de frames en la cola.
    
    bool recibirFrame(bool color, std::vector<unsigned char>& frame); // Recibe un frame desde el dispositivo FTDI.
    void bucleRecepcion(bool color); // Funcion principal del hilo.

};