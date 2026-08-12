#include "mainwindow.h"
#include <QMessageBox>
#include <QString>
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
            if (fuenteVideo.estaConectado() == false) // Dispositivo desconectado, conectar.
            {
                int dispositivo_i = ui.comboDispositivos->currentData().toInt(); // Usar el seleccionado en el ComboBox.
                if (fuenteVideo.conectar(dispositivo_i) == false)
                {
                    QMessageBox::critical(this, "Error FTDI.", "No se pudo abrir o configurar el dispositivo FTDI.");
                    return;
                }

                ui.buttonConectar->setText("Desconectar");
                ui.comboDispositivos->setEnabled(false);
                ui.labelVideo->setText("FTDI conectado");

                ui.buttonVideo->setText("Iniciar video");
                ui.buttonVideo->setEnabled(true);
                ui.checkBoxVideoColor->setEnabled(true);
            }
            else   // Dispositivo conectado, desconectar.
            {
                videoActivo = false;
                temporizadorVideo.stop();
                ui.buttonVideo->setText("Detener video");
                ui.buttonVideo->setEnabled(false);
                ui.checkBoxVideoColor->setEnabled(false);

                fuenteVideo.desconectar();

                ui.labelVideo->setText("Sin señal");
                ui.buttonConectar->setText("Conectar");
                ui.comboDispositivos->setEnabled(true);
                ui.labelFps->setText("0.0");

            }
        });

// BOTON VISUALIZAR VIDEO.
//===============================================
    connect(ui.buttonVideo, &QPushButton::clicked, this, [this]()
    {
        if (videoActivo) // Detener el video.
        {
            videoActivo = false;
            temporizadorVideo.stop();
            fuenteVideo.detenerRecepcion(); // Detener el bucle de recepcion y cerrar el hilo.

            ui.labelVideo->clear(); // Eliminar frame y mostrar texto de video detenido.
            ui.labelVideo->setText("Video detenido");
            ui.buttonVideo->setText("Iniciar video"); // Resto de botones
            ui.checkBoxVideoColor->setEnabled(true);
            ui.labelFps->setText("0.0");
        }
        else // Iniciar el video.
        {
            videoActivo = true;
            framesRecibidos = 0;
            temporizadorFps.start();
            fuenteVideo.iniciarRecepcion(videoColor);
            ui.buttonVideo->setText("Detener video");
            ui.checkBoxVideoColor->setEnabled(false);
            temporizadorVideo.start(10); // Solicitar el primer frame. Qt comprueba cada 10 ms si hay un frame nuevo disponible.
        }
    });

// CHECKBOX VISUALIZAR VIDEO A COLOR.
//===============================================
    ui.checkBoxVideoColor->setChecked(videoColor);
    ui.checkBoxVideoColor->setEnabled(false);

    connect(ui.checkBoxVideoColor, &QCheckBox::toggled, this, [this](bool checked)
        {
            videoColor = checked;
        });

// TEMPORIZADOR ENCARGADO DE SOLICITAR FRAMES.
//===============================================
    temporizadorVideo.setSingleShot(true); // El temporizador usado para pedir un frame, no se rearma automaticamente sino al terminar de recibir un frame.
    connect(&temporizadorVideo, &QTimer::timeout, this, &MainWindow::recibirFrame);  // Cuando el temporizador se agota, se llama a la funcion de solicitar un nuevo frame.
}


//===============================================
//  MOSTRAR VIDEO
//===============================================

// Solicita un frame al dispositivo FTDI, lee los 614400 bytes en formato YCbCr, lo transforma a RGB y lo muestra en el panel de video.
void MainWindow::recibirFrame()
{
    std::vector<unsigned char> frame; // Vector de bytes del frame recibido.
    if (!fuenteVideo.obtenerUltimoFrame(frame)) // Copia el ultimo frame recibido en el vector frame.
    {
        if(!fuenteVideo.estaRecibiendo()) // Si el hilo de recepcion se detuvo por algun error, detener el video.
        {
            videoActivo = false;
            fuenteVideo.detenerRecepcion(); // Detener el bucle de recepcion y cerrar el hilo.
            ui.buttonVideo->setText("Iniciar video");
            ui.checkBoxVideoColor->setEnabled(true);
            ui.labelFps->setText("0.0");
            QMessageBox::critical(this, "Error de recepcion.", "El hilo FTDI ha dejado de recibir frames");
            return; // No hay frame nuevo disponible, salir de la funcion.
        }
        temporizadorVideo.start(10); // El hilo sigue activo, pero no hay frame nuevo disponible, volver a comprobar en 10 ms.
        return;
    }
    
    QImage imagen;

    if (videoColor)
    {
        imagen = convertirFrameColor(frame);
    }
    else
    {
        imagen = convertirFrameBN(frame);
    }
    

    if (imagen.isNull())
    {
        videoActivo = false;
        ui.buttonVideo->setText("Iniciar video");
        QMessageBox::critical(this, "Error de imagen.", "No se pudo convertir el frame a RGB.");
        return;
    }

    // setPixmap requiere una imagen de tipo QPixmap. La ajusta a labelVideo manteniendo el ratio.
    QPixmap imagenEscalada = QPixmap::fromImage(imagen).scaled(ui.labelVideo->size(), Qt::KeepAspectRatio, Qt::SmoothTransformation);
    ui.labelVideo->setPixmap(imagenEscalada);

    // Calcular FPS.
    framesRecibidos++;
    if (temporizadorFps.elapsed() >= 1000) // Actualizar valor cada segundo.
    {
        double fps = framesRecibidos * 1000.0 / temporizadorFps.elapsed();
        ui.labelFps -> setText(QString::number(fps, 'f', 1));
        framesRecibidos = 0;
        temporizadorFps.restart();
    }

    // Solicitar nuevo frame.
    if (videoActivo)
    {
        temporizadorVideo.start(10); // Compueba cada 10 ms si hay un frame nuevo disponible.
    }
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
QImage MainWindow::convertirFrameColor(const std::vector<unsigned char>& frame)
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
            // ITU_R BT.656: Cb (Chroma U), Y0 (Luma), Cr (Chroma V), Y1.
            // Pixel 0: y0 + u + v. Pixel 1: y1 + u + v.
            int u = frame[posicion]; // Cb de ambos pixeles.
            int y0 = frame[posicion + 1]; // Luminosidad del pixel 0.
            int v = frame[posicion + 2]; // Cr de ambos pixeles.
            int y1 = frame[posicion + 3]; // Luminosidad del pixel 1.

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

// Convierte datos de video Y en píxeles RGB, formato que QImage necesita para mostrar colores.
QImage MainWindow::convertirFrameBN(const std::vector<unsigned char>& frame)
{
    const int ancho = 640;  // VGA.
    const int alto = 480;

    QImage imagen(ancho, alto, QImage::Format_RGB888);

    for (int y = 0; y < alto; y++)  // Cada linea ..
    {
        unsigned char* linea = imagen.scanLine(y);

        for (int x = 0; x < ancho; x ++)  // Cada byte es el valor luma Y del pixel.
        {
            int posicion = (y * ancho + x); // Indice en el vector de bytes del frame.
            // Posiciones RGB del pixel, todos equivalen al valor luma.
            linea[x * 3] = frame[posicion];
            linea[x * 3 + 1] = frame[posicion];
            linea[x * 3 + 2] = frame[posicion];
        }
    }

    return imagen;
}



MainWindow::~MainWindow()
{}

