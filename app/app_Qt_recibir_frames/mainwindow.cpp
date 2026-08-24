#include "mainwindow.h"
#include <QMessageBox> // Usado al mostrar errores criticos.
#include <QString>
#include <QImage> // Usado para manipular los frames.
#include <QPixmap> // Usado para mostrar los frames en la interfaz.
#include <opencv2/core/core.hpp> // Usado para la estructura de OpenCV cv::Mat.
#include <string> // Usado al cargar la ruta del archivo.
using namespace cv;

MainWindow::MainWindow(QWidget *parent)
    : QMainWindow(parent)
{
    ui.setupUi(this);  // Qt contruye todos los controladores en el interfaz visual.


//===============================================
//  CONECTAR DISPOSITIVO FTDI
//===============================================
    actualizarDispositivosFTDI();

// BOTON ACTUALIZAR DISPOSITIVOS FTDI.
//===============================================
    connect(ui.buttonActualizarDisp, &QPushButton::clicked, this, [this]()
        {
            actualizarDispositivosFTDI();
        });

// BOTON CONECTAR/DESCONECTAR DISPOSITIVO FTDI.
//===============================================
    connect(ui.buttonConectar, &QPushButton::clicked, this, [this]()
        {
            if (hiloFuenteVideo.dispFTDIConectado() == false) // Dispositivo desconectado, conectar.
            {
                int dispositivo_i = ui.comboDispositivos->currentData().toInt(); // Tomar el dispositivo seleccionado en el ComboBox.
                if (hiloFuenteVideo.conectarFTDI(dispositivo_i) == false)
                {
                    QMessageBox::critical(this, "Error FTDI.", "No se pudo abrir o configurar el dispositivo FTDI.");
                    return;
                }

                ui.buttonConectar->setText("Desconectar");
                ui.comboDispositivos->setEnabled(false);
                ui.buttonActualizarDisp->setEnabled(false);
                ui.labelVideo->setText("FTDI conectado");
                ui.buttonVideo->setText("Iniciar video");
                ui.buttonVideo->setEnabled(true);
                ui.checkBoxVideoColor->setEnabled(true);
                ui.checkBoxDetectarRostros->setEnabled(true);
                ui.checkboxCamshift->setEnabled(ui.checkBoxDetectarRostros->isChecked());
            }
            else // Dispositivo conectado, detener video y desconectar.
            {
                flagVideoActivo = false; // Deshabilita flag de lectura de frames de video.
                temporizadorSigFrame.stop(); // Detiene la comprobacion de nuevos frames.
                hiloFuenteVideo.desconectarFTDI(); // Desconecta la comunicacion con el dispositivo FTDI.
                hiloProcesadorVideo.detenerHiloProcesarFrames(); // Detiene el hilo de procesado con OpenCV.

                ui.buttonConectar->setText("Conectar");
                ui.comboDispositivos->setEnabled(true);
                ui.buttonActualizarDisp->setEnabled(true);
                ui.labelVideo->setText("Sin se�al de video.");
                ui.buttonVideo->setEnabled(false);
                ui.checkBoxVideoColor->setEnabled(false);
                ui.checkBoxDetectarRostros->setEnabled(false);
                ui.checkboxCamshift->setEnabled(false);
                ui.labelFps->setText("0.0");
            }
        });


// BOTON CONECTAR/DESCONECTAR DISPOSITIVO FTDI.
//===============================================
connect(ui.buttonReiniciarFPGA, &QPushButton::clicked, this, [this]()
    {
        comandoFPGA = 0x80; // 10000000.

        if (!hiloFuenteVideo.enviarComando(comandoFPGA))
        {
            QMessageBox::critical(this, "Error FTDI.", "No se pudo reiniciar la FPGA.");
        }
    }
);

// BOTON VISUALIZAR VIDEO.
//===============================================
    connect(ui.buttonVideo, &QPushButton::clicked, this, [this]()
    {
        if (flagVideoActivo) // Detener el video.
        {
            flagVideoActivo = false;
            temporizadorSigFrame.stop();
            hiloFuenteVideo.detenerHiloFuenteVideo(); // Detener el bucle de recepcion y cerrar el hilo.
            hiloProcesadorVideo.detenerHiloProcesarFrames(); // Detiene el hilo de procesado con OpenCV.

            ui.labelVideo->clear(); // Eliminar frame y mostrar texto de video detenido.
            ui.labelVideo->setText("Video detenido");
            ui.buttonVideo->setText("Iniciar video"); // Resto de botones
            ui.checkBoxVideoColor->setEnabled(true);
            ui.checkBoxDetectarRostros->setEnabled(true);
            ui.checkboxCamshift->setEnabled(ui.checkBoxDetectarRostros->isChecked());
            ui.labelFps->setText("0.0");
        }
        else // Iniciar el video.
        {
            if (detectarRostros)
            {
                const std::string rutaDetector = "C:/opencv-4.14.0/opencv/sources/data/haarcascades/haarcascade_frontalface_alt2.xml";
                if(!hiloProcesadorVideo.cargarClasificadorHaar(rutaDetector))
                {
                    QMessageBox::critical(this, "Error OpenCV.", "No se pudo cargar el detector de rostros.");
                    return;
                }

                const std::string rutaDetectorOjos = "C:/opencv-4.14.0/opencv/sources/data/haarcascades/haarcascade_eye_tree_eyeglasses.xml";
                if(!hiloProcesadorVideo.cargarClasificadorOjos(rutaDetectorOjos))
                {
                    QMessageBox::critical(this, "Error OpenCV.", "No se pudo cargar el detector de ojos.");
                    return;
                }
                hiloProcesadorVideo.usarCamShift(seguirRostros);
            }
            
            flagVideoActivo = true;
            hiloFuenteVideo.iniciarHiloFuenteVideo(videoColor);
            if (detectarRostros)
            {
                hiloProcesadorVideo.iniciarHiloProcesarFrames(); // Lanza el hilo para trabajar con OpenCV.
            }
            temporizadorFps.start();
            contFramesRecibidos = 0;
            temporizadorSigFrame.start(10); // Solicitar el primer frame. Qt comprueba cada 10 ms si hay un frame nuevo disponible.

            ui.buttonVideo->setText("Detener video");
            ui.checkBoxVideoColor->setEnabled(false);
            ui.checkBoxDetectarRostros->setEnabled(false);
            ui.checkboxCamshift->setEnabled(false);
        }
    });

// CHECKBOX VISUALIZAR VIDEO A COLOR.
//===============================================
    ui.checkBoxVideoColor->setChecked(videoColor);
    ui.checkBoxVideoColor->setEnabled(false); // Inicialmente desactivado.

    connect(ui.checkBoxVideoColor, &QCheckBox::toggled, this, [this](bool checked)
        {
            videoColor = checked; // Guarda el estado del checkbox.
        });

// CHECKBOX DETECTAR ROSTROS.
//===============================================
    ui.checkBoxDetectarRostros->setChecked(detectarRostros);
    ui.checkBoxDetectarRostros->setEnabled(false); // Inicialmente desactivado.

    connect(ui.checkBoxDetectarRostros, &QCheckBox::toggled, this, [this](bool checked)
        {
            detectarRostros = checked;
            ui.checkboxCamshift->setEnabled(checked && hiloFuenteVideo.dispFTDIConectado() && !flagVideoActivo);
            if (!checked)
            {
                ui.checkboxCamshift->setChecked(false);
            }
        });

// CHECKBOX SEGUIR ROSTROS CON CAMSHIFT.
//===============================================
    ui.checkboxCamshift->setChecked(seguirRostros);
    ui.checkboxCamshift->setEnabled(false); // Inicialmente desactivado.

    connect(ui.checkboxCamshift, &QCheckBox::toggled, this, [this](bool checked)
        {
            seguirRostros = checked;
        });

// TEMPORIZADOR ENCARGADO DE COMPROBAR LA LLEGADA DE FRAMES.
//===============================================
    temporizadorSigFrame.setSingleShot(true); // Temporizador NO ciclico, usado para pedir un frame, tras lo cual debe rearmarse.
    connect(&temporizadorSigFrame, &QTimer::timeout, this, &MainWindow::capturarUnFrame);  // Cuando el temporizador se agota, llama a la funcion de leer un nuevo frame.
}


//===============================================
//  MOSTRAR VIDEO
//===============================================

// Obtiene el ultimo frame recibido, lo convierte a RGB y lo muestra.
void MainWindow::capturarUnFrame()
{
    std::vector<unsigned char> frame; // Buffer local temporal para almacenar el frame recibido.
    if (!hiloFuenteVideo.obtenerUltimoFrame(frame)) // Obtniene el ultimo frame recibido desde el dispositivo FTDI.
    {
        if(!hiloFuenteVideo.recepcionActiva()) // Si el hilo de recepcion se detuvo por algun error, detener el video mostrado e indicar error.
        {
            flagVideoActivo = false;
            hiloFuenteVideo.detenerHiloFuenteVideo(); // Detener el bucle de recepcion y cerrar el hilo.
            hiloProcesadorVideo.detenerHiloProcesarFrames(); // Cierra el hilo de procesar frames usando OpenCV.
            ui.buttonVideo->setText("Iniciar video");
            ui.checkBoxVideoColor->setEnabled(true);
            ui.checkBoxDetectarRostros->setEnabled(true);
            ui.checkboxCamshift->setEnabled(ui.checkBoxDetectarRostros->isChecked());
            ui.labelFps->setText("0.0");
            QMessageBox::critical(this, "Error de recepcion.", "El hilo FTDI ha dejado de recibir frames");
            return; // No hay frame nuevo disponible, salir de la funcion.
        }
        temporizadorSigFrame.start(10); // El hilo sigue activo, pero no hay frame nuevo disponible, volver a comprobar en 10 ms.
        return;
    }
    
    QImage imagen; // Objeto imagen en Qt.

    if (videoColor)
    {
        imagen = convertirFrameColor(frame); // Frame desde FTDI tiene formato YCbCr 4:2:2.
    }
    else
    {
        imagen = convertirFrameBN(frame); // Frame desde FTDI en escala de grises o luminancia Y.
    }
    

    if (imagen.isNull()) // Imagen recibida invalida, detener video.
    {
        flagVideoActivo = false;
        temporizadorSigFrame.stop();
        hiloFuenteVideo.detenerHiloFuenteVideo();
        hiloProcesadorVideo.detenerHiloProcesarFrames();
        ui.buttonVideo->setText("Iniciar video");
        ui.checkBoxVideoColor->setEnabled(true);
        ui.checkBoxDetectarRostros->setEnabled(true);
        ui.checkboxCamshift->setEnabled(ui.checkBoxDetectarRostros->isChecked());
        ui.labelFps->setText("0.0");
        QMessageBox::critical(this, "Error de imagen.", "No se pudo convertir el frame recibido a RGB.");
        return;
    }

    // Crear un contenedor Mat de OpenCV apuntando a los datos Qimage.
    Mat frameOpenCV(imagen.height(), imagen.width(), CV_8UC3, imagen.bits(), imagen.bytesPerLine());
    frameOpenCV = frameOpenCV.clone(); // Clonar la imagen que luego sera enviada a otro hilo.
    Mat frameMostrado = frameOpenCV; // Por defecto mostrar la imagen sin procesado.
    if (detectarRostros)
    {
        hiloProcesadorVideo.procesarUnFrame(frameOpenCV); // Enviar la matriz al hilo de OpenCV.
        Mat frameProcesado;
        if(hiloProcesadorVideo.obtenerUltimoFrameProcesado(frameProcesado)) // Si se procesa correctamente, mostrar el resultado.
        {
            frameMostrado = frameProcesado;
        }
        else // Para evitar frames desordenados, si no se ha procesado un frame, no se cambia el mostrado actualmente.
        {
            if (flagVideoActivo)
            {
                temporizadorSigFrame.start(10);
            }
            return; 
        }
    }
    
    // Convertir Mat de OpenCV a formato para el interfaz de Qt.
    QImage imagen_desdeOpenCV(frameMostrado.data, frameMostrado.cols, frameMostrado.rows, static_cast<qsizetype>(frameMostrado.step), QImage::Format_RGB888);

    // setPixmap requiere una imagen de tipo QPixmap. La ajusta a labelVideo manteniendo el aspecto para no deformarla.
    QPixmap imagenEscalada = QPixmap::fromImage(imagen_desdeOpenCV).scaled(ui.labelVideo->size(), Qt::KeepAspectRatio, Qt::SmoothTransformation);
    ui.labelVideo->setPixmap(imagenEscalada);

    // Calcular FPS.
    contFramesRecibidos++;
    if (temporizadorFps.elapsed() >= 1000) // Actualizar valor cada segundo.
    {
        double fps = contFramesRecibidos * 1000.0 / temporizadorFps.elapsed();
        ui.labelFps -> setText(QString::number(fps, 'f', 1));
        contFramesRecibidos = 0;
        temporizadorFps.restart();
    }

    // Rearmar el temporizador para el siguiente frame si el video sigue activo.
    if (flagVideoActivo)
    {
        temporizadorSigFrame.start(10); // Comprueba cada 10 ms si hay un frame nuevo disponible.
    }
}

//===============================================
//  YCbCr 4:2:2 -> RGB888.
//===============================================

// Convierte datos de video YCbCr 4:2:2 en pi�xeles RGB de 8 bits, formato que QImage necesita.
QImage MainWindow::convertirFrameColor(const std::vector<unsigned char>& frame)
{
    const int ancho = 640;  // VGA.
    const int alto = 480;
    QImage imagen(ancho, alto, QImage::Format_RGB888);

    for (int y = 0; y < alto; y++)  // Cada linea ..
    {
        unsigned char* linea = imagen.scanLine(y); // Puntero de linea de imagen Qt.
        for (int x = 0; x < ancho; x += 2)  // Procesar pixeles de dos en dos, al estar la informacion de ambos pixeles compartida.
        {
            int posicion = (y * ancho + x) * 2; // Indice en el vector de bytes del frame recibido.
            // Componentes norma ITU_R BT.656: Cb (Chroma U), Y0 (Luma), Cr (Chroma V), Y1.
            // Pixel 0: y0 + u + v. Pixel 1: y1 + u + v.
            int u = frame[posicion]; // Chroma azul (Cb) compartido.
            int y0 = frame[posicion + 1]; // Luminancia del pixel 0.
            int v = frame[posicion + 2]; // Chroma rojo (Cr) compartido.
            int y1 = frame[posicion + 3]; // Luminancia del pixel 1.
            // Ajuste de offsets.
            int c0 = y0 - 16; // MT9V111 Developer Guide, CCIR 601/656 con Y limitado de 16 (negro) a 235 (blanco).
            int c1 = y1 - 16;
            int d = u - 128; // Chroma U y  Chroma V representan la diferencia de color anadido a Y, con el neutro en 128.
            int e = v - 128;
            // Expandir el intervalo de 16-235 a 0-255. 
            // BT.601 R = 1,164 x (Y - 16) + 1,596 x (V - 128)
            // BT.601 G = 1,164 x (Y - 16) - 0,391 x (U - 128) - 0,813 x (V - 128)
            // BT.601 B = 1,164 x (Y - 16) + 2,016 x (U - 128)
            // 1,164*256=298; 1,596*256=409; 0,391*256=100; 0,813*256=208; 2,016*256=516.
            int rojo0 = limitarColor((298 * c0 + 409 * e + 128) >> 8); // /256.
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

//===============================================
//  Luminancia Y -> RGB888.
//===============================================

// Convierte datos de video Y en pi�xeles RGB, usado por QImage.
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

//===============================================
//  AUX: Saturar valores de color.
//===============================================

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

void MainWindow::actualizarDispositivosFTDI()
{
    ui.comboDispositivos->clear();
    DWORD numDispositivo = 0;
    ftStatus = FT_CreateDeviceInfoList(&numDispositivo); // Devuelve los dispositivos conectados al PC.

    if (ftStatus != FT_OK)
    {
        QMessageBox::critical(this, "Error FTDI", "Error obteniendo la lista de dispositivos.");
        ui.buttonConectar->setEnabled(false);
        return;
    }

    for (DWORD i = 0; i < numDispositivo; i++) // Leer los detalles de cada dispositivo y anadirlo en el ComboBox.
    {
        DWORD flags = 0; // Parametros del nodo tipo _ft_device_list_info_node que devuelve FT_GetDeviceInfoDetail().
        DWORD type = 0;
        DWORD id = 0;
        DWORD locId = 0;
        char serialNumber[16] = {};
        char description[64] = {};
        FT_HANDLE ftHandle_aux = nullptr;
        ftStatus = FT_GetDeviceInfoDetail(i, &flags, &type, &id, &locId, serialNumber, description, &ftHandle_aux);

        if (ftStatus == FT_OK) // Incorporar dispositivo conectado al ComboBox.
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
    else
    {
        ui.buttonConectar->setEnabled(true);
    }
}

MainWindow::~MainWindow()
{}



