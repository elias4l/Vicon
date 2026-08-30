#include "logs.h"
#include <chrono>
#include <ctime>
#include <fstream> // Usados para trabajar con los logs (ofstream()).
#include <iomanip> // Usado para formatear la fecha (put_time()).
#include <mutex>
#include <Windows.h>

namespace
{
    std::mutex mutexLogs;
    std::wstring rutaArchivoLogs;
}

void escribirLog(const std::string& mensaje) // Crea fichero de logs desde la ultima conexion si no existe, y escribir el mensaje al final del archivo.
{
    std::lock_guard<std::mutex> lock(mutexLogs); // un acceso simultaneo al archivo de logs.
    auto fecha_hora = std::chrono::system_clock::now();
    std::time_t fecha_hora_t = std::chrono::system_clock::to_time_t(fecha_hora); // Formato estandar time_t.
    std::tm fecha_hora_local; // Formato estandar local.
    localtime_s(&fecha_hora_local, &fecha_hora_t);
    if (rutaArchivoLogs.empty()) // No se ha creado desde la ultima conexion del dispositivo FTDI.
    {
        wchar_t ruta[MAX_PATH]; // Ruta para la localizacion del archivo de logs.
        GetModuleFileNameW(nullptr, ruta, MAX_PATH); // Ejecutable actual.
        std::wstring rutaString(ruta); // Formato estandar wstring.
        rutaString = rutaString.substr(0, rutaString.find_last_of(L"\\/")); // Usar solo el directorio.
        wchar_t nombreArchivo[64];
        wcsftime(nombreArchivo, 64, L"registro_%Y-%m-%d_%H-%M-%S.log", &fecha_hora_local); // Crea archivo de log con la fecha y hora actual, en la ubicacion del ejecutable.
        rutaArchivoLogs = rutaString + L"\\" + nombreArchivo; // Nombre y ruta completo al archivo.
    }
    std::ofstream archivoLogs(rutaArchivoLogs, std::ios::app); // Abrir archivo creado.
    if (archivoLogs.is_open())
    {
        archivoLogs << std::put_time(&fecha_hora_local, "%Y-%m-%d %H:%M:%S    ") << mensaje << std::endl; // Anadir mensaje al final.
    }
}

void vaciarRutaLog() // Vaciar la ruta del ultimo archivo de logs usado.
{
    std::lock_guard<std::mutex> lock(mutexLogs);
    rutaArchivoLogs.clear();
}
