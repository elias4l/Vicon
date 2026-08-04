#include "mainwindow.h"
#include <QMessageBox>
#include <QString>

MainWindow::MainWindow(QWidget *parent)
    : QMainWindow(parent)
{
    ui.setupUi(this);

//===============================================
//  CONECTAR DISPOSITIVO FTDI
//===============================================
    DWORD numDispositivo = 0;
    ftStatus = FT_CreateDeviceInfoList(&numDispositivo);

    if (ftStatus != FT_OK)
    {
        QMessageBox::critical(this, "Error FTDI", "Error obteniendo la lista de dispositivos.");
        ui.buttonConectar->setEnabled(false);
        return;
    }

    for (DWORD i = 0; i < numDispositivo; i++) // Leer los detalles de cada dispositivo y anadirlo en el ComboBox.
    {
        DWORD flags = 0; // parametros del nodo tipo _ft_device_list_info_node que devuelve FT_GetDeviceInfoDetail().
        DWORD type = 0;
        DWORD id = 0;
        DWORD locId = 0;
        char serialNumber[16] = {};
        char description[64] = {};
        FT_HANDLE ftHandle_aux = nullptr;

        ftStatus = FT_GetDeviceInfoDetail(i, &flags, &type, &id, &locId, serialNumber, description, &ftHandle_aux);

        if (ftStatus == FT_OK)
        {
            QString texto = QString::number(i) + " | " + QString::fromLatin1(description) + " | " + QString::fromLatin1(serialNumber);
            ui.comboDispositivos->addItem(texto, static_cast<int>(i));
        }
    }

    if (numDispositivo == 0)
    {
        ui.comboDispositivos->addItem("No se encuentran dispositivos FTDI.");
        ui.buttonConectar->setEnabled(false);
    }

    connect(ui.buttonConectar, &QPushButton::clicked, this, [this]()
        {
            if (ftHandle == nullptr) // Dispositivo desconectado, conectar.
            {
                int dispositivo_i = ui.comboDispositivos->currentData().toInt(); // Usar el seleccionado en el ComboBox.
                ftStatus = FT_Open(dispositivo_i, &ftHandle);

                if (ftStatus != FT_OK)
                {
                    ftHandle = nullptr;
                    QMessageBox::critical(this, "Error al abrir el dispositivo FTDI.", "Error FT_Open: " + QString::number(ftStatus));
                    return;
                }

                // Configuracion al conectarse al dispositivo: 
                ftStatus = FT_SetTimeouts(ftHandle, 100, 100); // Tiempo (ms) maximo de espera para lectura y escritura.
                if (ftStatus == FT_OK)
                {
                    ftStatus = FT_SetUSBParameters(ftHandle, 65536, 65536); // Tamano maximo del buffer en el PC asociado al controlador D2XX.
                }
                if (ftStatus == FT_OK)
                {
                    ftStatus = FT_SetLatencyTimer(ftHandle, 4); // Para video mejor usar latencia minima tras recibir datos. Max 255.
                }
                if (ftStatus == FT_OK)
                {
                    ftStatus = FT_Purge(ftHandle, FT_PURGE_RX | FT_PURGE_TX);
                }

                if (ftStatus != FT_OK)
                {
                    FT_Close(ftHandle);
                    ftHandle = nullptr;
                    QMessageBox::critical(this, "Error al configurar el dispositivo FTDI.", "Error: " + QString::number(ftStatus));
                    return;
                }

                ui.buttonConectar->setText("Desconectar");
                ui.comboDispositivos->setEnabled(false);
                ui.labelVideo->setText("FTDI conectado");
            }
            else   // Dispositivo conectado, desconectar.
            {
                FT_Close(ftHandle);
                ftHandle = nullptr;

                ui.buttonConectar->setText("Conectar");
                ui.comboDispositivos->setEnabled(true);
                ui.labelVideo->setText("Sin señal");
                ui.labelFps->setText("0.0");
            }
        });
}

MainWindow::~MainWindow()
{}

