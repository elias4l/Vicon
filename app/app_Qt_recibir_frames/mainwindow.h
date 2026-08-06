#pragma once

#include <QtWidgets/QMainWindow>
#include "ui_mainwindow.h"
#include "ftd2xx.h" // Libreria del controlador FTDI FT232H.
#include <QImage> // Para trabajar con imagenes.
#include <QTimer>
#include <QElapsedTimer> // Para clacular fps.
#include <vector>

class MainWindow : public QMainWindow
{
    Q_OBJECT

public:
    MainWindow(QWidget *parent = nullptr);
    ~MainWindow();

private:
    Ui::MainWindowClass ui;
    // Handler usado para el uso del dispositivo FTDI FT232H.
    FT_HANDLE ftHandle = nullptr;
    FT_STATUS ftStatus;
    // Comandos transmitidos.
    const std::uint8_t CMD_LEER_FRAME = 0x01; // BIT0 indica transmitir un frame.
    const std::uint8_t CMD_COLOR = 0x02; // BIT1 indica color (1) o BN (0).
    const std::uint8_t CMD_RESET = 0x80; // BIT7 indica RESET en la FPGA.
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
};

