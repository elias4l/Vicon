#pragma once

#include <QtWidgets/QMainWindow>
#include "ui_mainwindow.h"
#include "ftd2xx.h" // Libreria del controlador FTDI FT232H.
#include <QImage> // Para trabajar con imagenes.
#include <QTimer>
#include <QElapsedTimer> // Para clacular fps.
#include <vector>
#include "fuentevideo.h" // Clase que realiza la recepcion de frames.

class MainWindow : public QMainWindow
{
    Q_OBJECT

public:
    MainWindow(QWidget *parent = nullptr);
    ~MainWindow();

private:
    Ui::MainWindowClass ui;
    // Handler usado para el uso del dispositivo FTDI FT232H.
    FT_STATUS ftStatus;
    unsigned char comando = 0;
    // Metodos para trabajar con el frame.
    void recibirFrame();
    QImage convertirFrameColor(const std::vector<unsigned char>& frame);
    QImage convertirFrameBN(const std::vector<unsigned char>& frame);
    int limitarColor(int valor);
    // Variables para recibir video y calcular los FPS.
    QTimer temporizadorVideo; // Indica cuando solicitar el siguiente frame.
    QElapsedTimer temporizadorFps;
    bool videoActivo = false;
    bool videoColor = false;
    int framesRecibidos = 0;
    // Objeto para la recepcion de frames usando un hilo separado.
    FuenteVideo fuenteVideo;
};

