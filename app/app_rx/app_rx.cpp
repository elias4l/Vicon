#include <iostream>
#include <iomanip>
#include <Windows.h>
#include <conio.h>
#include "ftd2xx.h"

// Este programa recibe continuamente bytes del dispositivo FTDI y los muestra en hexadecimal.
// Usa las funciones de la libreria ftd2xx.h proporcionada por el fabricante FTDI.

int main() {
    FT_HANDLE ftHandle = nullptr;
    FT_STATUS ftStatus;

    unsigned char buffer[65536]; // Recepcion de bytes del driver D2XX.
    DWORD n = 0; // Numero de bytes recibidos.

    ftStatus = FT_Open(2, &ftHandle); // Abrir el dispositivo FTDI de indice 0.

    if (ftStatus != FT_OK) {
        std::cout << "Error FT_Open: " << ftStatus << "\n";
        return 1;
    }

    // Configuracion del handler.
    FT_SetTimeouts(ftHandle, 50, 100);
    FT_SetUSBParameters(ftHandle, 65536, 65536); // Tamanos de buffers USB internos del driver D2XX.
    FT_SetLatencyTimer(ftHandle, 1); // Enviar los datos en un maximo de 1 ms.
    FT_Purge(ftHandle, FT_PURGE_RX | FT_PURGE_TX); // Limpiar los buffers antes de comenzar.

    std::cout << "Lectura continua. Pulsa ESC para salir.\n";

    // Bucle de lectura continua.
    while (true) {
        if (_kbhit() && _getch() == 27) {   // ESC.
            break;
        }

        ftStatus = FT_Read(ftHandle, buffer, sizeof(buffer), &n);

        if (ftStatus != FT_OK) {
            std::cout << "Error FT_Read: " << ftStatus << "\n";
            break;
        }

        if (n == 0) {
            continue;
        }

        // Mostrar los bytes recibidos en hexadecimal.
        std::cout << "Bytes recibidos: " << n << "\nHEX  : ";

        for (DWORD i = 0; i < n; i++) {
            std::cout << std::hex << std::uppercase << std::setw(2)
                      << std::setfill('0') << static_cast<int>(buffer[i]) << ' '; // Muestra cada byte en dos digitos hexadecimales.
        }

        std::cout << std::dec << "\n";
    }

    FT_Close(ftHandle); // Cerrar el dispositivo FTDI.
    return 0;
}
