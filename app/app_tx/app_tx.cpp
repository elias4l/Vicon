// app_tx.cpp : Este archivo contiene la función "main". La ejecución del programa comienza y termina ahí.
//

#include <iostream>
#include <iomanip>
#include <limits>
#include <Windows.h>
#include <conio.h>
#include "include/ftd2xx.h"

// Este programa transmite un numero contenido en un byte.
// Usa las funciones de la libreria ftd2xx.h proporcionada por el fabricante FTDI.

int main() {
    FT_HANDLE ftHandle = nullptr;
    FT_STATUS ftStatus;

    ftStatus = FT_Open(2, &ftHandle); // Cambiar si es necesario.

    if (ftStatus != FT_OK) {
        std::cout << "Error FT_Open: " << ftStatus << "\n";
        return 1;
    }

    // Configuracion del handler.
    FT_SetTimeouts(ftHandle, 50, 100);
    FT_SetUSBParameters(ftHandle, 65536, 65536);
    FT_SetLatencyTimer(ftHandle, 1);
    FT_Purge(ftHandle, FT_PURGE_RX | FT_PURGE_TX);

    std::cout << "Transmisor FTDI. Pulsa 'e' para enviar un numero, ESC para salir.\n";

    // Bucle de transmision.
    while (true) {
        if (_kbhit()) {
            int ch = _getch();

            if (ch == 27) {
                break;
            }

            if (ch == 'e' || ch == 'E') {
                int value = 0;
                std::cout << "Introduce un numero del 1 al 8: ";

                if (!(std::cin >> value)) {
                    std::cin.clear();
                    std::cin.ignore((std::numeric_limits<std::streamsize>::max)(), '\n');
                    std::cout << "Entrada no valida.\n";
                    continue;
                }

                std::cin.ignore((std::numeric_limits<std::streamsize>::max)(), '\n');

                if (value < 1 || value > 8) {
                    std::cout << "Valor fuera de rango. Debe ser un numero entre 1 y 8.\n";
                    continue;
                }

                unsigned char data = static_cast<unsigned char>(value);
                DWORD bytesWritten = 0;
                ftStatus = FT_Write(ftHandle, &data, 1, &bytesWritten);

                if (ftStatus != FT_OK) {
                    std::cout << "Error FT_Write: " << ftStatus << "\n";
                    continue;
                }

                if (bytesWritten != 1) {
                    std::cout << "Error: " << bytesWritten << " bytes transmitidos.\n";
                    continue;
                }

                std::cout << "Byte enviado: " << value
                          << " (0x" << std::uppercase << std::hex
                          << std::setw(2) << std::setfill('0')
                          << static_cast<int>(data) << ")\n";
                std::cout << std::dec;
            }
            else {
                std::cout << "Tecla no asignada.\n";
            }
        }

        Sleep(10);
    }

    FT_Close(ftHandle);
    return 0;
}

