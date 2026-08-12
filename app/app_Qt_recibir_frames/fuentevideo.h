#pragma once

#include "ftd2xx.h"
#include <vector> // Para trabajar con frames.
#include <thread>
#include <atomic> // Para el uso de variables compartidas entre hilos.
#include <mutex> 
#include <deque> // Para almacenar los frames recibidos en un buffer de varios frames.

class FuenteVideo
{
public:
    FuenteVideo() = default; // Constructor.
    ~FuenteVideo(); // Destructor.
    bool conectar(int indiceDispositivo);
    void desconectar();
    bool estaConectado() const; // Funcion de consulta para saber si el dispositivo esta conectado.
    void iniciarRecepcion(bool color);
    void detenerRecepcion();
    bool obtenerUltimoFrame(std::vector<unsigned char>& frame); // Copia el ultimo frame recibido en el vector frame.
    bool estaRecibiendo() const; // Para detectar en MainWindow si el hilo de recepcion esta activo o se detuvo por algun error.

private:
    FT_HANDLE ftHandle = nullptr;
    
    std::thread hiloRecepcion;
    std::atomic<bool> recepcionActiva{ false }; // Flag para indicar la recepcion de frames.

    std::deque<std::vector<unsigned char>> colaFrames; // Buffer de frames recibidos aun sin mostrar.
    std::mutex mutexCola; // Mutex para proteger el acceso a la cola de los frames compartidos.
    const size_t MAX_FRAMES_COLA = 3; // Limite de frames en la cola, para no saturar la memoria.
    
    bool recibirFrame(bool color, std::vector<unsigned char>& frame); // Recibe un frame del dispositivo FTDI.
    void bucleRecepcion(bool color);

};