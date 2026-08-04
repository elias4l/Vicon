#pragma once

#include <QtWidgets/QMainWindow>
#include "ui_mainwindow.h"
#include "ftd2xx.h" // Libreria del controlador FTDI FT232H.
#include <QImage> // Para trabajar con imagenes.
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
    // Metodos para trabajar con el frame.
    void recibirFrame();
    QImage convertirFrame(const std::vector<unsigned char>& frame);
    int limitarColor(int valor);
};

