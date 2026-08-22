#include "procesarvideo.h"
#include <opencv2/imgproc/imgproc.hpp>
#include <opencv2/video/tracking.hpp> // Usado con el algoritmo Camshift.
#include <vector>


ProcesarVideo::~ProcesarVideo()
{
    detenerHiloProcesarFrames(); // Detiene el hilo activo.
}

bool ProcesarVideo::cargarClasificadorHaar(const std::string& ruta)
{
    return clasificadorCascadaHaar.load(ruta); // Cargar archivo .xml con el algoritmo de cascada Haar.
}

void ProcesarVideo::iniciarHiloProcesarFrames()
{
    if (flagDeteccionRostrosActivo) // No hacer nada si ya esta iniciado y procesando.
    {
        return;
    }
    if (hiloDeteccionRostros.joinable()) // Si el hilo estaba activo sin procesar, finalizarlo.
    {
        hiloDeteccionRostros.join();
    }

    flagDeteccionRostrosActivo = true; // Flag de control del hilo activado.
    hiloDeteccionRostros = std::thread(&ProcesarVideo::bucleProcesarFrame, this); // Iniciar hilo con funcion principal bucleProcesamiento().
}

void ProcesarVideo::detenerHiloProcesarFrames()
{
    flagDeteccionRostrosActivo = false; // Flag de ejecucion del bucle principal desactivado.
    frameDisponible.notify_all(); // Despierta el hilo si estaba suspendido en espera de recibir un frame.

    if (hiloDeteccionRostros.joinable())
    {
        hiloDeteccionRostros.join(); // Finalizar hilo.
    }

    {
        std::lock_guard<std::mutex> bloqueo(mutexFrames); // Mutex para sincronizar los frames usados en varios hilos.
        framePendienteProcesar.release(); // Eliminar memoria del frame recibido a procesar.
        ultimoFrameProcesado.release(); // Eliminar memoria del frame procesado a devolver.
        hayFramePendienteProcesar = false;
    }
    // Variables usadas con Camshift reestablecidas.
    seguimientoRostroActivo = false;
    contadorFramesSeguimientoRostro = 0;
    ventanaSeguimiento = Rect();
    tamanoVentanaSeguimiento = Size();
    histogramaH.release();
}

void ProcesarVideo::procesarUnFrame(const Mat& frame)
{
    if(!flagDeteccionRostrosActivo || frame.empty()) // Si el hilo esta desactivado o el frame es nulo, no hacer nada.
    {
        return;
    }
    {
        std::lock_guard<std::mutex> bloqueo(mutexFrames); 
        framePendienteProcesar = frame; // Sobreescribir con el frame mas reciente.
        hayFramePendienteProcesar = true; // Indicador pendiente.
    }
    frameDisponible.notify_one(); // Notificar al hilo de que hay un frame pendiente por procesar.
}

bool ProcesarVideo::obtenerUltimoFrameProcesado(Mat& frame)
{
    std::lock_guard<std::mutex> bloqueo(mutexFrames); // Acceso protegido a ultimoFrame.
    if(ultimoFrameProcesado.empty())
    {
        return false; // Nada que procesar.
    }

    frame = ultimoFrameProcesado; // Asignar frame.
    ultimoFrameProcesado.release(); // Liberar memoria.
    return true;
}

// Inicializa histograma en la ROI detectada por el algoritmo Haar.
bool ProcesarVideo::iniciarSeguimientoRostro(const Mat& frame, const Rect& region)
{
    Rect limites(0, 0, frame.cols, frame.rows); // Limitar la ROI a los limites del frame.
    ventanaSeguimiento = region & limites;
    if (ventanaSeguimiento.width <= 0 || ventanaSeguimiento.height <= 0) // ROI fuera de rango, salir.
    {
        return false;
    }

    tamanoVentanaSeguimiento = ventanaSeguimiento.size(); // Guardar el tamano de la ROI detectado por Haar.
    int vmin = 10; // Brillo minimo (sin negros).
    int vmax = 256; // Brillo maximo.
    int smin = 30; // Saturacion minima (sin grises/blancos).
    int tamanoHistograma = 16; // Bins en el histograma del tono o Hue.

    Mat hsv, tono, mascara; // Matrices temporales

    cvtColor(frame, hsv, COLOR_RGB2HSV); // Pasar frame de RGB a HSV.
    inRange(hsv, Scalar(0, smin, vmin), Scalar(180, 256, vmax), mascara); // Mascara, descarta zonas fuera de rango en brillo (V) y saturacion (S).
    
    tono.create(hsv.size(), hsv.depth()); // Mascara donde guardar el tono del frame.
    int canales[] = { 0, 0 };
    mixChannels(&hsv, 1, &tono, 1, canales, 1); // Obtener de la mascara unicamente el canal 0, tono o Hue.

    if (countNonZero(mascara(ventanaSeguimiento)) == 0) // Comprobar que la mascara del ROI tiene pixeles validos y no son todos 0.
    {
        return false;
    }
    Mat roiTono(tono, ventanaSeguimiento); // ROI de la mascara unicamente con los pixeles del tono.
    Mat roiMascara(mascara, ventanaSeguimiento); // ROI de la mascara.

    float rangoTono[] = { 0.0f, 180.0f }; // Rango dinamico del canal Hue usado en OpenCV.
    const float* rangoHistograma = rangoTono;
    int canalHistograma[] = { 0 }; // Procesar unicamente el primer canal, tono.

    calcHist(&roiTono, 1, canalHistograma, roiMascara, histogramaH, 1, &tamanoHistograma, &rangoHistograma); // Calcular el histograma de color de la ROI, usando la mascara.
    if (histogramaH.empty())
    {
        return false;
    }
    normalize(histogramaH, histogramaH, 0, 255, NORM_MINMAX); // Escalar histograma entre 0 y 255.
    seguimientoRostroActivo = true; // Activar seguimiento por color.
    contadorFramesSeguimientoRostro = 0; // Contador frames Camshift.
    return true;
}

// Rastrea el rostro segun el histograma calculado en iniciarCamshift().
bool ProcesarVideo::actualizarSeguimientoRostro(const Mat& frame)
{
    if (!seguimientoRostroActivo || histogramaH.empty() || ventanaSeguimiento.width <= 0 || ventanaSeguimiento.height <= 0)
    {
        return false; // Salir si se ha desactivado el seguimiento, o si el histograma o la ventana son incorrectas.
    }

    Rect limites(0, 0, frame.cols, frame.rows); // Limitar la ventana de seguimiento con el frame.
    ventanaSeguimiento = ventanaSeguimiento & limites;
    if (ventanaSeguimiento.width <= 0 || ventanaSeguimiento.height <= 0)
    {
        return false;
    }

    int vmin = 10; // Mismos valores que en iniciarCamshift().
    int vmax = 256;
    int smin = 30;
    Mat hsv; // Temporales.
    Mat tono;
    Mat mascara;
    Mat backProjection;

    cvtColor(frame, hsv, COLOR_RGB2HSV); // Igual que en iniciarCamshift(). Pasar el frame al espacio de colores HSV.
    inRange(hsv, Scalar(0, smin, vmin), Scalar(180, 256, vmax), mascara); // Mascara, descarta zonas fuera de rango en brillo (V) y saturacion (S).

    tono.create(hsv.size(), hsv.depth());  // Mascara donde guardar el tono del frame.
    int canales[] = { 0, 0 };
    mixChannels(&hsv, 1, &tono, 1, canales, 1); // Obtener de la mascara unicamente el canal 0, tono o Hue.

    float rangoTono[] = { 0.0f, 180.0f }; // Rango dinamico del canal Hue usado en OpenCV.
    const float* rangoBackProjection = rangoTono;
    int canalBackProjection[] = { 0 };

    calcBackProject(&tono, 1, canalBackProjection, histogramaH, backProjection, &rangoBackProjection); // Calculo de retroproyeccion, cada pixel ahora representa la probabilidad de pertenecer al histograma.
    backProjection &= mascara; // Descartar zonas segun la mascara de saturacion y brillo.

    Rect ventanaCamShift = ventanaSeguimiento; // Ventana usada por CamShift().
    RotatedRect cajaSeguimiento = CamShift(backProjection, ventanaCamShift, TermCriteria(TermCriteria::EPS | TermCriteria::COUNT, 10, 1)); // Algoritmo CamShift. Parada en 10 iteraciones o si cambio < 1 pixel.
    if (cajaSeguimiento.size.width <= 1.0f || cajaSeguimiento.size.height <= 1.0f)
    {
        return false; // Abortar si el cuadro colapsa.
    }
    if (tamanoVentanaSeguimiento.width <= 0 || tamanoVentanaSeguimiento.height <= 0 || tamanoVentanaSeguimiento.width > frame.cols || tamanoVentanaSeguimiento.height > frame.rows)
    {
        return false;
    }

    int nuevaX = static_cast<int>(cajaSeguimiento.center.x) - tamanoVentanaSeguimiento.width / 2; // Centro de la nueva posicion calculada.
    int nuevaY = static_cast<int>(cajaSeguimiento.center.y) - tamanoVentanaSeguimiento.height / 2;
    if (nuevaX < 0) // Mantener dentro cuadro dentro del frame.
    {
        nuevaX = 0;
    }
    if (nuevaY < 0)
    {
        nuevaY = 0;
    }
    if (nuevaX + tamanoVentanaSeguimiento.width > frame.cols)
    {
        nuevaX = frame.cols - tamanoVentanaSeguimiento.width;
    }
    if (nuevaY + tamanoVentanaSeguimiento.height > frame.rows)
    {
        nuevaY = frame.rows - tamanoVentanaSeguimiento.height;
    }
    ventanaSeguimiento = Rect(nuevaX, nuevaY, tamanoVentanaSeguimiento.width, tamanoVentanaSeguimiento.height);
    return true;
}

// Lanza la deteccion Haar seguida de seguimiento de rostro con CamShift().
void ProcesarVideo::bucleProcesarFrame()
{
    while(true)
    {
        Mat frame; // Aqui se guarda el frame sobre el que se realiza el procesamiento con OpenCV.
        {
            std::unique_lock<std::mutex> bloqueo(mutexFrames); // Bloquear acceso compartido al frame, y suspender el hilo mientras espera al siguiente frame por procesar o si se detiene todo el procesamiento de frames.
            frameDisponible.wait(bloqueo, [this]() 
            {
                return !flagDeteccionRostrosActivo || hayFramePendienteProcesar;
            });

            if(!flagDeteccionRostrosActivo) // Finalizar bucle si el hilo se desperto para ello.
            {
                break;
            }

            frame = framePendienteProcesar; // Copiar nuevo frame.
            framePendienteProcesar.release(); // Liberar memoria.
            hayFramePendienteProcesar = false;
        }

        Mat resultado = frame.clone(); // Copia sobre la que dibujar los resultados.

        if (!seguimientoRostroActivo || contadorFramesSeguimientoRostro >= FRAMES_CAMSHIFT) // Haar se ejecuta al comenzar el bucle, al perder el seguimiento, o tras 10 frames con seguimiento.
        {
            Mat frameGris; // Haar trabaja en escala de grises.
            cvtColor(frame, frameGris, COLOR_RGB2GRAY);

            std::vector<Rect> caras; // Vector dinamico donde guardar los rostros detectados.
            clasificadorCascadaHaar.detectMultiScale(frameGris, caras, 1.1, 3, 0, Size(30, 30), Size(500, 500)); // Deteccion de rostros multiescala.
            int areaMayor = 0; // Seleccionar el rostro de mayor area.
            Rect caraMayor; // Estructura para guardar el rostro del rostro con mayor area.
            for (int i = 0; i < static_cast<int>(caras.size()); i++)
            {
                int areaCara = caras[i].width * caras[i].height; // Area de la cara i.
                if (areaCara > areaMayor) // Guardar si rostro i es el mayor.
                {
                    areaMayor = areaCara;
                    caraMayor = caras[i];
                }
            }

            if (areaMayor > 0) // Hay al menos un rostro.
            {
                seguimientoRostroActivo = iniciarSeguimientoRostro(frame, caraMayor); // Usar el mayor rostro detectado con Haar para inicializar CamShift.
                rectangle(resultado, caraMayor, Scalar(0, 255, 0), 2); // Mostrar con un recuadro verde.
                if (!seguimientoRostroActivo) // Si CamShift() falla.
                {
                    contadorFramesSeguimientoRostro = 0;
                    histogramaH.release(); // Liberar memoria de histograma.
                }
            }
            else // No hay ningun rostro que pueda utilizarse para iniciar CamShift.
            {
                seguimientoRostroActivo = false; // Detener seguimiento.
                contadorFramesSeguimientoRostro = 0;
                histogramaH.release(); // Liberar memoria de histograma.
            }
        }
        else // En los frames intermedios se utiliza CamShift.
        {
            seguimientoRostroActivo = actualizarSeguimientoRostro(frame);
            if (seguimientoRostroActivo)
            {
                contadorFramesSeguimientoRostro++;
                rectangle(resultado, ventanaSeguimiento, Scalar(0, 0, 255), 2); // Azul: region seguida mediante CamShift.
            }
            else // Si CamShift pierde la region, se vuelve a ejecutar Haar.
            {
                contadorFramesSeguimientoRostro = 0;
                histogramaH.release();
            }
        }

        {
            std::lock_guard<std::mutex> bloqueo(mutexFrames);
            ultimoFrameProcesado = resultado; // Sobreescribir frame con el nuevo resultado.
        }
    }
}
