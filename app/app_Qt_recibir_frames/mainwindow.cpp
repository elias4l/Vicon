#include "mainwindow.h"
#include <QMessageBox>
#include <QString>
#include <vector>
#include <QElapsedTimer>
#include <QImage>
#include <QPixmap>

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

                ui.buttonVideo->setEnabled(true);
            }
            else   // Dispositivo conectado, desconectar.
            {
                FT_Close(ftHandle);
                ftHandle = nullptr;

                ui.buttonConectar->setText("Conectar");
                ui.comboDispositivos->setEnabled(true);
                ui.labelVideo->setText("Sin señal");
                ui.labelFps->setText("0.0");

                ui.buttonVideo->setEnabled(false);
            }
        });

    // Boton de visualizar video.
    connect(ui.buttonVideo, &QPushButton::clicked, this, &MainWindow::recibirFrame);

}


//===============================================
//  MOSTRAR VIDEO
//===============================================

// Solicita un framet al dispositivo FTDI, lee los 614400 bytes en formato YCbCr, lo transforma a RGB y lo muestra en el panel de video.
void MainWindow::recibirFrame()
{
    const DWORD frameBytes = 640 * 480 * 2;

    // Eliminamos si hubiera por error bytes antiguos antes de pedir el nuevo frame.
    ftStatus = FT_Purge(ftHandle, FT_PURGE_RX | FT_PURGE_TX);

    if (ftStatus != FT_OK)
    {
        QMessageBox::critical(this, "Error FT_Purge.", "Error al limpiar los buffers.");
        return;
    }

    // La FPGA utiliza el comando 7 para solicitar el envio de un unico frame.
    unsigned char comando = 7;
    DWORD bytesEscritos = 0;

    ftStatus = FT_Write(ftHandle, &comando, 1, &bytesEscritos);

    if (ftStatus != FT_OK || bytesEscritos != 1)
    {
        QMessageBox::critical(this, "Error FT_Write.", "Error al solicitar el frame.");
        return;
    }

    std::vector<unsigned char> frame(frameBytes);

    DWORD bytesLeidosTotales = 0;
    QElapsedTimer tiempo; // Timeout de lectura del frame.
    tiempo.start();

    while (bytesLeidosTotales < frameBytes)
    {
        DWORD bytesLeidos = 0; // En cada llamada a FT_Read().
        DWORD bytesPorLeer = frameBytes - bytesLeidosTotales;
        // Tamano maximo del buffer.
        if (bytesPorLeer > 65536)
        {
            bytesPorLeer = 65536;
        }

        ftStatus = FT_Read(ftHandle, &frame[bytesLeidosTotales], bytesPorLeer, &bytesLeidos);

        if (ftStatus != FT_OK)
        {
            QMessageBox::critical(this, "Error FT_Read.", "Error al llamar a FT_Read.");
            return;
        }

        bytesLeidosTotales += bytesLeidos;

        // Evita quedarse esperando de forma indefinida si la FPGA no responde. Max 1s.
        if (tiempo.elapsed() > 1000)
        {
            QMessageBox::critical(this, "Error lectura de frame.", "Tiempo superior a 1 segundo.");
            return;
        }
    }

    QImage imagen = convertirFrame(frame);

    if (imagen.isNull())
    {
        QMessageBox::critical(this, "Error de imagen.", "No se pudo convertir el frame a RGB.");
        return;
    }

    // setPixmap requiere una imagen de tipo QPixmap. La ajusta a labelVideo manteniendo el ratio.
    QPixmap imagenEscalada = QPixmap::fromImage(imagen).scaled(ui.labelVideo->size(), Qt::KeepAspectRatio, Qt::SmoothTransformation);
    ui.labelVideo->setPixmap(imagenEscalada);
}

// Valores RGB nunca debe salir del rango 0-255.
int MainWindow::limitarColor(int valor)
{
    if (valor < 0)
    {
        return 0;
    }
    if (valor > 255)
    {
        return 255;
    }
    return valor;
}

// Convierte datos de video YCbCr 4:2:2 en píxeles RGB, formato que QImage necesita para mostrar colores.
QImage MainWindow::convertirFrame(const std::vector<unsigned char>& frame)
{
    const int ancho = 640;  // VGA.
    const int alto = 480;

    QImage imagen(ancho, alto, QImage::Format_RGB888);

    for (int y = 0; y < alto; y++)  // Cada linea ..
    {
        unsigned char* linea = imagen.scanLine(y);

        for (int x = 0; x < ancho; x += 2)  // Procesar de dos en dos al estar la informacion de ambos pixeles compartida.
        {
            int posicion = (y * ancho + x) * 2; // Indice en el vector de bytes del frame.
            //Pixel 0: y0 + u + v. Pixel 1: y1 + u + v,
            int y0 = frame[posicion]; // Luminosidad del pixel 0.
            int v = frame[posicion + 1]; // Cr de ambos pixeles.
            int y1 = frame[posicion + 2]; // Luminosidad del pixel 1.
            int u = frame[posicion + 3]; // Cb de ambos pixeles.

            int c0 = y0 - 16; // MT9V111 Developer Guide, CCIR 601/656 con Y limitado de 16 (negro) a 235 (blanco).
            int c1 = y1 - 16;
            int d = u - 128; // U y V representan la diferencia de color anadido a Y, con el neutro en 128.
            int e = v - 128;
            // Expandir el intervalo de 16…235 a 0…255. 
            // BT.601 R = 1,164 × (Y - 16) + 1,596 × (V - 128)
            // BT.601 G = 1,164 × (Y - 16) - 0,391 × (U - 128) - 0,813 × (V - 128)
            // BT.601 B = 1,164 × (Y - 16) + 2,016 × (U - 128)
            // 1,164*256=298; 1,596*256=409; 0,391*256=100; 0,813*256=208; 2,016*256=516.
            int rojo0 = limitarColor((298 * c0 + 409 * e + 128) >> 8);
            int verde0 = limitarColor((298 * c0 - 100 * d - 208 * e + 128) >> 8);
            int azul0 = limitarColor((298 * c0 + 516 * d + 128) >> 8);
            int rojo1 = limitarColor((298 * c1 + 409 * e + 128) >> 8);
            int verde1 = limitarColor((298 * c1 - 100 * d - 208 * e + 128) >> 8);
            int azul1 = limitarColor((298 * c1 + 516 * d + 128) >> 8);

            // Posiciones RGB de ambos pixeles.
            linea[x * 3] = rojo0;
            linea[x * 3 + 1] = verde0;
            linea[x * 3 + 2] = azul0;
            linea[(x + 1) * 3] = rojo1;
            linea[(x + 1) * 3 + 1] = verde1;
            linea[(x + 1) * 3 + 2] = azul1;
        }
    }

    return imagen;
}



MainWindow::~MainWindow()
{}

