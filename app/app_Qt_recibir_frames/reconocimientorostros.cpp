#include "reconocimientorostros.h"
#include <opencv2/imgcodecs.hpp> // Para cargar las imagenes.
#include <opencv2/imgproc.hpp> // Para procesar las imagenes.

bool ReconocimientoRostros::preprocesarRostro(const cv::Mat& frameGris, const cv::Rect& ventana, cv::Mat& rostroNormFila) const
{
    cv::Rect ventanaR = ventana & cv::Rect(0, 0, frameGris.cols, frameGris.rows);
    if (ventanaR.width <= 0 || ventanaR.height <= 0) return false;
    cv::Mat rostroNormalizado;
    cv::resize(frameGris(ventanaR), rostroNormalizado, cv::Size(64, 64)); // RostroNormalizado tiene el rostro de la ventana en el frame, con tamano 64x64 pixeles.
    cv::equalizeHist(rostroNormalizado, rostroNormalizado); // Equilibra el contraste para que sea mas independiente del nivel de iluminacion.
    rostroNormalizado.convertTo(rostroNormalizado, CV_32F, 1.0 / 255.0); // Pasar los pixeles a float de 32 bits, y factorizar por 1/255. Ahora cada pixel tiene un valo de 0.0 a 1.0, con los que trabaja el renocoedor de OpenCV.
    rostroNormFila = rostroNormalizado.reshape(1, 1).clone(); // 64x64 a 1x4096.
    return true;
}

bool ReconocimientoRostros::cargarRostros(const std::string& carpeta, cv::CascadeClassifier& clasificadorHaar) // Carga los rostros, obtiene sus nombres, entrena clasificador KNN.
{
    if (reconocedorEntrenado)
        return true; // No volver a entrenar.

    std::vector<cv::String> archivosCargados;
    cv::glob(carpeta + "/*.png", archivosCargados, false);

    if (archivosCargados.empty()) // No hay rostros de referencia en la carpeta.
        return false;

    cv::Mat rostrosKNN, etiquetas;
    vectorNombres.clear();
    for (int i = 0; i < archivosCargados.size(); i++)
    {
        cv::Mat imagen_i = cv::imread(archivosCargados[i]); // Cargar imagen.
        if (imagen_i.empty())
            continue;
        cv::Mat imagen_i_gris;
        cv::cvtColor(imagen_i, imagen_i_gris, cv::COLOR_BGR2GRAY); // Pasar a gris.
        cv::Mat imagen_i_eq;
        cv::equalizeHist(imagen_i_gris, imagen_i_eq);

        // Buscar rostros
        std::vector<cv::Rect> rostros;
        clasificadorHaar.detectMultiScale(imagen_i_eq, rostros, 1.1, 3); // 

        if (rostros.size() == 0) // Imagen de referencia no reconocida en el frame.
            continue;
        
        cv::Rect rostroMayor = rostros[0];
        for (int j = 1; j < rostros.size(); j++) // Hallar el rostro más grande entre los reconocidos.
        {
            if (rostros[j].area() > rostroMayor.area())
            {
                rostroMayor = rostros[j];
            }
        }

        cv::Mat rostroKNN;
        if (!preprocesarRostro(imagen_i_eq, rostroMayor, rostroKNN)) // Preparar el rostro para el KNN
            continue;

        
        std::string ruta = archivosCargados[i];
        size_t posicionBarra = ruta.find_last_of("/\\");
        std::string nombre; // El nombre de la carpeta es el nombre del individuo.

        if (posicionBarra == std::string::npos)
            nombre = ruta;
        else
            nombre = ruta.substr(posicionBarra + 1);
        
        size_t posicionPunto = nombre.find_last_of('.'); // Quitar .png

        if (posicionPunto != std::string::npos)
            nombre = nombre.substr(0, posicionPunto);


        size_t posicionGuion = nombre.find_last_of('_'); // Quitar _x del nombre.
        if (posicionGuion != std::string::npos)
            nombre = nombre.substr(0, posicionGuion);

        if (nombre.empty())
            continue;

        int etiqueta = -1;
        for (int j = 0; j < vectorNombres.size(); j++) // Comprobar si el nombre ya tiene una etiqueta.
        {
            if (vectorNombres[j] == nombre)
            {
                etiqueta = j;
                break;
            }
        }
        if (etiqueta == -1) // Crear etiqueta si es la primera vez.
        {
            vectorNombres.push_back(nombre);
            etiqueta = (int)vectorNombres.size() - 1;
        }

        // Añadir datos de entrenamiento
        rostrosKNN.push_back(rostroKNN);
        etiquetas.push_back((float)etiqueta);
    }

    if (rostrosKNN.empty()) // Si no se encontró ningún rostro salir.
        return false;

    // Entrenar KNN
    reconocedorKNN->train(rostrosKNN, cv::ml::ROW_SAMPLE, etiquetas);
    reconocedorEntrenado = true;
    return true;
}

std::string ReconocimientoRostros::reconocerRostro(const cv::Mat& frameGris, const cv::Rect& ventana) const // Usa el reconocedor entrenado para comprobar si un rostro pertenece a algun individuo registrado.
{
    if (reconocedorEntrenado == false) // Error, entrenar primero.
    {
        return "Desconocido";
    }

    cv::Mat muestraPreprocesada;
    if (preprocesarRostro(frameGris, ventana, muestraPreprocesada) == false) // Error, la ventana esta fuera de rango.
    {
        return "Desconocido";
    }

    cv::Mat resultados, vecinos, distancias;
    reconocedorKNN->findNearest(muestraPreprocesada, 1, resultados, vecinos, distancias); // Busca el rostro aportado entre los registrados en el entrenamiento KNN. Devolver 1 vecino mas cercano.

    int etiqueta = (int)resultados.at<float>(0, 0); // findNearest devulve una matriz de resultados. Obtenemos el unico valor en fila 0 columna 0.
    float distancia = distancias.at<float>(0, 0);
    if ((distancia > UMBRAL_KNN) || (etiqueta < 0) || (etiqueta >= vectorNombres.size()))
    {
        return "Desconocido " + std::to_string((int)distancia);
    }

    return vectorNombres[etiqueta];
}
