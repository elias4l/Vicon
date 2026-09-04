// app_tx.cpp : Este archivo contiene la funcion "main". La ejecución del programa comienza y termina ahí.
//

#include <iostream>
#include <iomanip>
#include <limits>
#include <fstream>
#include <string>
#include <Windows.h>
#include <conio.h>
#include "include/ftd2xx.h"

// Este programa transmite un numero contenido en un byte.
// Usa las funciones de la libreria ftd2xx.h proporcionada por el fabricante FTDI.

int main() {
    FT_HANDLE ftHandle = nullptr;
    FT_STATUS ftStatus;

    std::ofstream log("recepcion.log", std::ios::out | std::ios::trunc);

    if (!log.is_open()) {
        std::cout << "No se pudo crear recepcion.log\n";
        return 1;
    }

    // Bloque para imprimir los dispositivos FTDI conectados.
    DWORD numDevs = 0;
    ftStatus = FT_CreateDeviceInfoList(&numDevs);

    if (ftStatus != FT_OK) {
        std::cout << "Error obteniendo lista de dispositivos\n";
        return 1;
    }

    std::cout << "Dispositivos FTDI encontrados: " << numDevs << "\n\n";

    for (DWORD i = 0; i < numDevs; i++) {
        DWORD flags, type, id, locId;
        char serial[16];
        char description[64];
        FT_HANDLE tempHandle;

        ftStatus = FT_GetDeviceInfoDetail(
            i,
            &flags,
            &type,
            &id,
            &locId,
            serial,
            description,
            &tempHandle);

        if (ftStatus == FT_OK) {
            std::cout << "Indice: " << i << '\n';
            std::cout << "  Descripcion : " << description << '\n';
            std::cout << "  Serie       : " << serial << '\n';
            std::cout << "  LocID       : 0x" << std::hex << locId << std::dec << '\n';
            std::cout << "  Tipo        : " << type << "\n\n";
        }
    }
    //--



    int dispositivo_i = -1;

    std::cout << "Introduce el numero del dispositivo FTDI UM232H-B conectado: ";
    std::cin >> dispositivo_i;
    if (dispositivo_i < 0) {
        std::cout << "Indice erroneo.\n";
        return 1;
    }
    ftStatus = FT_Open(dispositivo_i, &ftHandle);

    if (ftStatus != FT_OK) {
        std::cout << "Error FT_Open: " << ftStatus << "\n";
        return 1;
    }

    // Configuracion del handler.
    FT_SetTimeouts(ftHandle, 50, 100);
    FT_SetUSBParameters(ftHandle, 65536, 65536);
    FT_SetLatencyTimer(ftHandle, 1);
    FT_Purge(ftHandle, FT_PURGE_RX | FT_PURGE_TX);

    std::cout << "Transmisor FTDI. Pulsa 'e' para enviar un numero, 'p' para purgar buffers, 'l' para leer, 'ESC' para salir.\n";

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
            else if (ch == 'p' || ch == 'P') {
                DWORD rx = 0, tx = 0, events = 0;
                FT_GetStatus(ftHandle, &rx, &tx, &events);

                std::cout << "En el buffer rx habia: " << rx << " bytes, y en el buffer tx habia: " << tx << " bytes\n";

                FT_Purge(ftHandle, FT_PURGE_RX | FT_PURGE_TX);
                std::cout << "Buffers purgados.\n";
            }
            else if (ch == 'l' || ch == 'L') {
                std::cout << "Modo lectura. Pulsa ESC para salir.\n";

                unsigned char datos[65536];

                while (true) {
                    if (_kbhit()) {
                        int tecla = _getch();

                        if (tecla == 27) {
                            break;
                        }
                    }

                    DWORD disponibles = 0;
                    FT_GetQueueStatus(ftHandle, &disponibles);

                    if (disponibles > 0) {
                        DWORD a_leer = disponibles;

                        if (a_leer > static_cast<DWORD>(sizeof(datos))) {
                            a_leer = static_cast<DWORD>(sizeof(datos));
                        }

                        DWORD leidos = 0;
                        ftStatus = FT_Read(
                            ftHandle,
                            datos,
                            a_leer,
                            &leidos);

                        if (ftStatus != FT_OK) {
                            std::cout << "Error FT_Read: " << ftStatus << '\n';
                            break;
                        }

                        if (leidos > 0) {
                            std::string salida;
                            salida.reserve(static_cast<size_t>(leidos) * 8);

                            for (DWORD i = 0; i < leidos; i++) {
                                salida += "RX: ";
                                salida += std::to_string(
                                    static_cast<unsigned int>(datos[i]));
                                salida += '\n';
                            }

                            log.write(
                                salida.data(),
                                static_cast<std::streamsize>(salida.size()));
                            log.flush();

                            std::cout.write(
                                salida.data(),
                                static_cast<std::streamsize>(salida.size()));
                            std::cout.flush();
                        }
                    }
                    else {
                        Sleep(1);
                    }
                }
            }
            else {
                std::cout << "Tecla no asignada.\n";
            }
        }

        Sleep(10);
    }

    log.close();
    FT_Close(ftHandle);
    return 0;
}
