#pragma once

#include <QtWidgets/QMainWindow>
#include "ui_mainwindow.h"
#include "ftd2xx.h" // Libreria del controlador FTDI FT232H.
#include <QImage> // Para trabajar con imagenes.
#include <QTimer>
#include <QElapsedTimer> // Para clacular fps.
#include <vector>
#include "fuentevideo.h" // Clase que realiza la recepcion de frames.
#include "procesarvideo.h"

class MainWindow : public QMainWindow
{
    Q_OBJECT

public:
    MainWindow(QWidget *parent = nullptr);
    ~MainWindow();

private:
    Ui::MainWindowClass ui; // Estructura de la interfaz grafica generada por Qt.
    FT_STATUS ftStatus; // Estado de las llamadas a la libreria ftd2xx.
    unsigned char comandoFPGA = 0; // Byte usado para enviar ordenes a la FPGA.
    // Video.
    bool flagVideoActivo = false; // Flag que indica si la reproduccion de video esta activa.
    bool videoColor = false; // Indica si se ha seleccionado video a color.
    bool detectarRostros = false; // Indica si se ha seleccionado la deteccion de rostros con OpenCV.
    bool seguirRostros = false; // Indica si se ha seleccionado el seguimiento de rostros con CamShift.
    QTimer temporizadorSigFrame; // Temporizador sigle-shot para indicar cuando comprobar el siguiente frame.
    QElapsedTimer temporizadorFps; // Mide el tiempo para calcular los fps.
    int contFramesRecibidos = 0; // En un segundo.
    //Hilos
    FuenteVideo hiloFuenteVideo; // Recepcion del frame desde la FPGA.
    ProcesarVideo hiloProcesadorVideo; // Bucle para procesar los frames usando OpenCV.

    // Metodos para trabajar con el frame.
    void capturarUnFrame(); // Funcion principal captura -> procesado -> mostrar.
    QImage convertirFrameColor(const std::vector<unsigned char>& frame); // Pasa de YUV a RGB.
    QImage convertirFrameBN(const std::vector<unsigned char>& frame); // Pasa de Y a RGB en escala de grises.
    int limitarColor(int valor); // Recorta a un valor entre 0 y 255.
    void actualizarDispositivosFTDI(); // Actualiza los dispositivos FTDI disponibles en el ComboBox.
};


