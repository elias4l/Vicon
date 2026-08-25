#pragma once

#include <opencv2/core.hpp>
#include <opencv2/ml.hpp> // Para usar KNearest.
#include <opencv2/objdetect.hpp> // Para CascadeClassifier.
#include <string>
#include <vector>

class ReconocimientoRostros
{
public:
    bool cargarRostros(const std::string& carpeta, cv::CascadeClassifier& clasificadorHaar); // Carga la carpeta con rostros conocidos para el clasificador Haar.
    std::string reconocerRostro(const cv::Mat& frameGris, const cv::Rect& region) const; // Identifica un rostro y devuelve su informacion.

private:
    bool preprocesarRostro(const cv::Mat& frameGris, const cv::Rect& ventana, cv::Mat& muestraNum) const; // Normaliza los rostros a 64x64 pixeles.
    cv::Ptr<cv::ml::KNearest> reconocedorKNN = cv::ml::KNearest::create(); // Puntero de la clase de OpenCV que implementa el algoritmo KNN: reconoce el rostro entre los N vecinos.
    std::vector<std::string> vectorNombres;
    bool reconocedorEntrenado = false; // Indica si el reconocedor ya ha cargado las fotografias.
    const float UMBRAL_KNN = 300.0f; // Diferencia maxima para reconocer un rostro.
};
