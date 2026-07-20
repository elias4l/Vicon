#include <iostream>
#include <Windows.h>    // DWORD
#include <chrono>       // medir tiempo
#include "ftd2xx.h"     // FT_Open, FT_Read, ...

// Este programa recibe bytes del dispositivo FTDI y calcula la tasa de bytes por segundos.
// // Usa las funciones de la libreria ftd2xx.h proporcionada por el fabricante FTDI.

int main() {
    FT_HANDLE ftHandle = nullptr;
    FT_STATUS ftStatus;

    unsigned char buffer[65536];    // Recepcion bytes del driver D2XX
    DWORD n = 0;
    unsigned long long cont = 0;


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

    ftStatus = FT_Open(2, &ftHandle);   // Abrir FT232H

    if (ftStatus != FT_OK) {
        std::cout << "Error FT_Open: " << ftStatus << "\n";
        return 1;
    }

    // Configuracion del handler.
    FT_SetTimeouts(ftHandle, 50, 100);
    FT_SetUSBParameters(ftHandle, 65536, 65536);    // Tamaños de buffers USB internos del driver D2XX
    FT_SetLatencyTimer(ftHandle, 1);    // Enviar en max. 1 ms.
    FT_Purge(ftHandle, FT_PURGE_RX | FT_PURGE_TX);

    auto t_start = std::chrono::steady_clock::now();

    while (true) {
        ftStatus = FT_Read(ftHandle, buffer, sizeof(buffer), &n);

        if (ftStatus != FT_OK) {
            std::cout << "Error FT_Read: " << ftStatus << "\n";
            break;
        }

        cont += n;

        auto t_now = std::chrono::steady_clock::now();

        if (t_now - t_start >= std::chrono::seconds(1)) {
            double segundos = std::chrono::duration_cast<std::chrono::microseconds>(t_now - t_start).count() / 1000000.0;
            double mbps = cont / segundos / 1024.0 / 1024.0;    // MBps.
            std::cout << mbps << " MB/s\n";
            cont = 0;
            t_start = t_now;
        }
    }

    FT_Close(ftHandle);
    return 0;
}