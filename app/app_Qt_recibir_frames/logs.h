#pragma once

#include <string>

void escribirLog(const std::string& mensaje); // Crea fichero de logs desde la ultima conexion si no existe, y escribir el mensaje al final del archivo.
void vaciarRutaLog(); // Vaciar la ruta del ultimo archivo de logs usado.
