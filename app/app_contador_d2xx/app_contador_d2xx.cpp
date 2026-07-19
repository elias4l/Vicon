#include <iostream>
#include <Windows.h>    // DWORD
#include <conio.h>  // _kbhit(), _getch()
#include "ftd2xx.h" // FT_Open, FT_Read, ...

// Este programa recibe bytes del dispositivo FTDI y espera recibir el valor de un contador que se incrementa de forma secuencial.
// // Usa las funciones de la libreria ftd2xx.h proporcionada por el fabricante FTDI.
// Verifica que cada byte recibido es igual al anterior +1, indicando fallo en consola en caso contrario.
int main() {
    FT_HANDLE ftHandle = nullptr;   // dispositivo FTDI abierto. void*
    FT_STATUS ftStatus;

    unsigned char c = 0;    // byte actual
    unsigned char c_next = 0;   // byte consecutivo
    DWORD n = 0;    // Numero de bytes leidos.
    unsigned cont_sec_no_ordenada = 0; // Contador de numeros no consecutivos recibidos.

    ftStatus = FT_Open(2, &ftHandle);       // Abrir dispositivo FTDI, en mi caso el dispositivo conerctado numero 2.

    if (ftStatus != FT_OK) {
        std::cout << "Error FT_Open: " << ftStatus << "\n";
        return 1;
    }

    // Configuracion del handler
    FT_SetTimeouts(ftHandle, 50, 100);  // Tiempo maximo de retraso en lectura 50ms. La FPGA incrememnta el contador cada 10ms.
    FT_Purge(ftHandle, FT_PURGE_RX | FT_PURGE_TX);  // Purgado inicial RX y TX.
    ftStatus = FT_Read(ftHandle, &c, 1, &n);    // Lee un byte.

    if (ftStatus != FT_OK || n != 1) {
        std::cout << "No se pudo leer el primer byte\n";
        FT_Close(ftHandle);
        return 1;
    }

    while (true) {
        ftStatus = FT_Read(ftHandle, &c_next, 1, &n);   // Lee siguiente byte en la FIFO del dispositivo FT232H.

        if (ftStatus != FT_OK || n != 1) {
            std::cout << "Error o timeout de lectura\n";
            break;
        }

        bool ordenada = (c_next == static_cast<unsigned char>(c + 1));  // Asi 255 + 1 = 0

        if (!ordenada) {
            cont_sec_no_ordenada++; // Fallo.
        }

        std::cout << "Recibido: " << static_cast<int>(c)
            << ", Total fallos: " << cont_sec_no_ordenada
            << "\n";

        c = c_next;

        
        if (_kbhit()) { // Si ESC salir
            int tecla = _getch();
            if (tecla == 27) {
                break;
            }
        }
    }

    FT_Close(ftHandle); // Cerrar FTDI

    std::cout << "Programa cerrado correctamente.\n";
    return 0;
}