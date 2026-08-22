#pragma once

#include <opencv2/core/core.hpp> // Estructuras OpenCV basicas (Mat, Rect, Size, Scalar).
#include <opencv2/objdetect/objdetect.hpp> // Para usar el clasificador en cascada Haar.
#include <thread>
#include <atomic>
#include <mutex>
#include <condition_variable> // Para suspender el hilo si no se usa.
#include <string>

using namespace cv; // Evita usar cv:: en los objetos de OpenCV.

class ProcesarVideo
{
public:
    ProcesarVideo() = default;
    ~ProcesarVideo();

    bool cargarClasificadorHaar(const std::string& ruta); // Carga el modelo de deteccion de caras Haar.
    void iniciarHiloProcesarFrames(); // Inicia el hilo OpenCV.
    void detenerHiloProcesarFrames(); // Detiene el hilo.
    void procesarUnFrame(const Mat& frame); // Usado por MainWindow para enviar un frame a procesar.
    bool obtenerUltimoFrameProcesado(Mat& frame); // Usado por MainWindows para obtener el frame procesado.

private:
    void bucleProcesarFrame(); // Bucle principal del hilo.
    bool iniciarSeguimientoRostro(const Mat& frame, const Rect& region); // Inicializa el histograma para luego actualizar la posicion del rostro detectado.
    bool actualizarSeguimientoRostro(const Mat& frame); // Modifica la posicion del rostro detectado.

    CascadeClassifier clasificadorCascadaHaar; // Objeto OpenCV para realizar la deteccion de rosotros usando Haar.

    Rect ventanaSeguimiento; // Contiene la posicion y tamano del area de seguimiento del rostro.
    Size tamanoVentanaSeguimiento;
    Mat histogramaH; // Del canal H (HSV) usado por el rostro detectado.
    bool seguimientoRostroActivo = false; // Indica si Camshift esta rastreando un rostro.
    int contadorFramesSeguimientoRostro = 0;
    const int FRAMES_CAMSHIFT = 10; // Numero de frames que camshift rastrea antes de volver a detectar rostros de nuevo.

    std::thread hiloDeteccionRostros;
    std::atomic<bool> flagDeteccionRostrosActivo{ false }; // Flag atomico que mantiene el hilo activo.

    Mat framePendienteProcesar; // Frame enviado desde MainWindow para su procesado con OpenCV. 
    Mat ultimoFrameProcesado; // Frame a ser enviado a MainWindow.
    bool hayFramePendienteProcesar = false; // Indica si hay frames por procesar.

    std::mutex mutexFrames;
    std::condition_variable frameDisponible; // Despierta el hilo, asociado a la llegada de un nuevo frame desde MainWindow.
};
