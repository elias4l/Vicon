#include "procesarvideo.h"
#include "logs.h"
#include <opencv2/imgproc/imgproc.hpp> // Usado en cvtColr(), calcHist(), rectangle() ..
#include <opencv2/video/tracking.hpp> // Usado con el algoritmo Camshift.
#include <vector> // Almacenar los rostros, ventanas para Camshift, ..
#include <algorithm> // Gestion de los rostros detectados.


ProcesarVideo::~ProcesarVideo()
{
    detenerHiloProcesarFrames(); // Detiene el hilo activo.
}

bool ProcesarVideo::cargarClasificadorHaar(const std::string& ruta)
{
    return clasificadorCascadaHaar.load(ruta); // Cargar archivo .xml con el algoritmo de cascada Haar.
}

bool ProcesarVideo::cargarClasificadorOjos(const std::string& ruta)
{
    return clasificadorOjosHaar.load(ruta); // Cargar archivo .xml con el algoritmo de cascada Haar para ojos.
}

bool ProcesarVideo::cargarRostros(const std::string& carpeta)
{
    return reconocimientoRostros.cargarRostros(carpeta, clasificadorCascadaHaar);
}

void ProcesarVideo::usarCamShift(bool valor) // Establece el indicador privado para usar o no Camshift.
{
    usarSeguimientoCamShift = valor;
}

void ProcesarVideo::usarReconocimiento(bool valor)
{
    usarReconocimientoRostros = valor;
}

void ProcesarVideo::iniciarHiloProcesarFrames()
{
    if (flagProcesarVideoActivo) // No hacer nada si ya esta iniciado y procesando.
    {
        return;
    }
    if (hiloDeteccionRostros.joinable()) // Si el hilo estaba activo sin procesar, o pendiente de recoger, finalizarlo.
    {
        hiloDeteccionRostros.join();
    }

    flagProcesarVideoActivo = true; // Flag de control del bucle principal en el hilo activado.
    hiloDeteccionRostros = std::thread(&ProcesarVideo::bucleProcesarFrames, this); // Iniciar hilo con funcion principal bucleProcesamiento().
}

void ProcesarVideo::detenerHiloProcesarFrames()
{
    flagProcesarVideoActivo = false; // Flag de ejecucion del bucle principal desactivado.
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
    ventanasSeguimiento.clear();
    histogramasGris.clear();
    nombresSeguimiento.clear();
}

// Obtiene el frame e indica que hay un nuevo frame por procesar.
void ProcesarVideo::procesarUnFrame(const Mat& frame)
{
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
bool ProcesarVideo::iniciarSeguimientoRostro(const Mat& frame, const Rect& region, Rect& ventana, Mat& histograma)
{
    Rect limites(0, 0, frame.cols, frame.rows); // Limitar la ROI a los limites del frame.
    ventana = region & limites;
    if (ventana.width <= 0 || ventana.height <= 0) // ROI fuera de rango, salir.
    {
        return false;
    }

    int tamanoHistograma = 32; // Bins en el histograma de intensidad.
    int vmin = 10; // Intensidad minima, descarta pixeles casi negros.
    int vmax = 245; // Intensidad maxima, descarta pixeles casi blancos.
    float rangoGris[] = { 0.0f, 256.0f }; // Rango de intensidad. [0, 256) , de 0 a 255.
    const float* rangoHistograma = rangoGris; // Puntero al rango, usado por calcHist().

    Mat frameGris;
    if (frame.channels() == 3) // RGB.
    {
        cvtColor(frame, frameGris, COLOR_RGB2GRAY); // Pasa a escala de grises.
    }
    else
    {
        frameGris = frame;
    }

    Mat mascara;
    inRange(frameGris, Scalar(vmin), Scalar(vmax), mascara); // Mascara binaria, descarta blancos y negros. 255: intensidad entre vmin y vmax. 0: intensidad fuera del intervalo.
    Mat roi(frameGris, ventana); // Parte del frame dentro de ventana.
    Mat roiMascara(mascara, ventana); // Parte de la mascara dentro de ventana.
    Mat histogramaFrame, histogramaRostro;
    calcHist(&frameGris, 1, 0, mascara, histogramaFrame, 1, &tamanoHistograma, &rangoHistograma); // Intensidades dentro del frame.
    calcHist(&roi, 1, 0, roiMascara, histogramaRostro, 1, &tamanoHistograma, &rangoHistograma); // Intensidades dentro del rostro.
    if (histogramaFrame.empty() || histogramaRostro.empty())
    {
        return false;
    }
    normalize(histogramaRostro, histogramaRostro, 1, 0, NORM_L1); // Valor normalizado a 1, en vez de absolutos.
    normalize(histogramaFrame, histogramaFrame, 1, 0, NORM_L1);
    histogramaFrame += 0.000001f; // Para evitar posibles divisiones por cero en divide().
    divide(histogramaRostro, histogramaFrame, histograma);
    normalize(histograma, histograma, 0, 255, NORM_MINMAX);
    return true;
}

// Rastrea el rostro segun el histograma calculado en iniciarSeguimientoRostro().
bool ProcesarVideo::actualizarSeguimientoRostro(const Mat& frame, Rect& ventana, const Mat& histograma)
{
    if (histograma.empty() || ventana.width <= 0 || ventana.height <= 0)
    {
        return false; // Salir si el histograma o la ventana son incorrectas.
    }

    Rect limites(0, 0, frame.cols, frame.rows); // Limitar la ventana de seguimiento con el frame.
    ventana = ventana & limites;
    if (ventana.width <= 0 || ventana.height <= 0)
    {
        return false;
    }

    Mat frameGris;
    if (frame.channels() == 3)
    {
        cvtColor(frame, frameGris, COLOR_RGB2GRAY);
    }
    else
    {
        frameGris = frame;
    }

    Mat backproj; // Imagen de retroporyeccion, para indicar los pixeles que mas se parecen al histograma del rostro.
    int vmin = 10; // Mismos limites de intensidad usados al calcular el histograma.
    int vmax = 245;
    float rangoGris[] = { 0.0f, 256.0f };
    const float* rangoBackProjection = rangoGris;

    calcBackProject(&frameGris, 1, 0, histograma, backproj, &rangoBackProjection); // A mas peso tengo un nivel de gris en el rostro, mayor valor en backproj.

    Mat mascara; // Usar solo los pixeles con niveles de gris validos.
    inRange(frameGris, Scalar(vmin), Scalar(vmax), mascara);
    backproj &= mascara;
    threshold(backproj, backproj, 32, 255, THRESH_TOZERO); // Eliminar de de backproj los coincidencias con el hostograma poco fuertes (<32).

    int anchoAnterior = ventana.width; // Conservar el tamano anterior de la ventana de seguimiento.
    int altoAnterior = ventana.height;
    RotatedRect cajaSeguimiento = CamShift(backproj, ventana, TermCriteria(TermCriteria::EPS | TermCriteria::COUNT, 10, 1)); // Actualizar posicion del rostro, usando Camshift y backproj. Parte desde ventana, y busca los pixeles donde el parecido tiene mayor intensidad. 10 iteraciones o precision de 1 pixel.
    if (cajaSeguimiento.size.width <= 1.0f || cajaSeguimiento.size.height <= 1.0f)
    {
        return false; // Abortar si el cuadro colapsa.
    }

    int nuevaX = static_cast<int>(cajaSeguimiento.center.x) - anchoAnterior / 2; // Conservar el centro calculado por CamShift.
    int nuevaY = static_cast<int>(cajaSeguimiento.center.y) - altoAnterior / 2;
    nuevaX = std::max(0, std::min(nuevaX, frame.cols - anchoAnterior)); // Mantener la ventana dentro del frame.
    nuevaY = std::max(0, std::min(nuevaY, frame.rows - altoAnterior));
    ventana = Rect(nuevaX, nuevaY, anchoAnterior, altoAnterior); // Reconstruir con las dimensiones anteriores.

    ventana = ventana & limites;
    if (ventana.width <= 0 || ventana.height <= 0)
    {
        return false;
    }
    return true;
}

// Funcion principal del hilo. Lanza la deteccion Haar seguida de seguimiento de rostro con CamShift().
void ProcesarVideo::bucleProcesarFrames()
{
    while(true)
    {
        Mat frame; // Aqui se guarda el frame sobre el que se realiza el procesamiento con OpenCV.
        {
            std::unique_lock<std::mutex> bloqueo(mutexFrames); // Bloquear acceso compartido al frame, y suspender el hilo mientras espera al siguiente frame por procesar. Libera el mutex mientras espera, lo adquiere al despertar.
            frameDisponible.wait(bloqueo, [this]() 
            {
                return !flagProcesarVideoActivo || hayFramePendienteProcesar; 
            }); // Cierra lamda y llama a wait().

            if(!flagProcesarVideoActivo) // Finalizar bucle si se ordena detener el procesamiento.
            {
                break; // Detener bucle while.
            }

            frame = framePendienteProcesar; // Copiar nuevo frame.
            framePendienteProcesar.release(); // frame mantiene la referencia.
            hayFramePendienteProcesar = false; // Frame adquirido.
        }

        Mat frameProcesado = frame.clone(); // Copia sobre la que dibujar los resultados del procesamiento.

        Mat frameGris; // Haar y CamShift trabajan con el mismo frame en escala de grises mejorado.
        if (frame.channels() == 3)
        {
            cvtColor(frame, frameGris, COLOR_RGB2GRAY);
        }
        else
        {
            frameGris = frame.clone();
        }
        equalizeHist(frameGris, frameGris); // Mejorar el contraste antes de aplicar Haar y CamShift.
        Mat frameGrisCompleto = frameGris;
        resize(frameGris, frameGris, Size(320, 240)); // Procesar a mitad de resolucion para reducir el coste de la deteccion.

        if (!usarSeguimientoCamShift || !seguimientoRostroActivo || contadorFramesSeguimientoRostro >= FRAMES_CAMSHIFT) // Haar se ejecuta en cada frame sin CamShift, al perder el seguimiento, o tras 10 frames con seguimiento.
        {
            std::vector<Rect> rostros; // Vector dinamico donde guardar los rostros detectados.
            clasificadorCascadaHaar.detectMultiScale(frameGris, rostros, 1.1, 3, 0, Size(24, 24), Size(250, 250)); // Buscar rostros en framegris y guardarlos en el vector caras. Factor de escala del 10%, 3 detecciones vecinas minimas, y entre 24 y 250 px de lado.

            // Ordenar los rostros por area para seleccionar como maximo los cuatro mayores.
            std::sort(rostros.begin(), rostros.end(), [](const Rect& caraA, const Rect& caraB)
            {
                return caraA.area() > caraB.area();
            });

            ventanasSeguimiento.clear(); // Nueva deteccion Haar.
            histogramasGris.clear();
            nombresSeguimiento.clear();
            int rostrosAceptados = 0; // Rosotros validos, es decir con al menos un ojo.
            for (int i = 0; (i < static_cast<int>(rostros.size())) && (rostrosAceptados < MAX_ROSTROS); i++)
            {
                // Detectar ojos en cada rostro detectado.
                Rect rostroMostrado(rostros[i].x * 2, rostros[i].y * 2, rostros[i].width * 2, rostros[i].height * 2);
                Mat rostroRoi = frameGrisCompleto(rostroMostrado);
                std::vector<Rect> ojos;    // Vector de los ojos descubiertos
                clasificadorOjosHaar.detectMultiScale(rostroRoi, ojos, 1.1, 2, 0, Size(3, 3)); // Ahora se usa el clasificador de los ojos.
                if (ojos.empty()) // Rostro no valido.
                {
                    continue;
                }
                rostrosAceptados++;
                rectangle(frameProcesado, rostroMostrado, Scalar(0, 255, 0), 2); // Mostrar con un recuadro verde el rostro valido.
                std::string nombreRostro;
                if (usarReconocimientoRostros) // Nombre reconocido.
                {
                    nombreRostro = reconocimientoRostros.reconocerRostro(frameGrisCompleto, rostroMostrado);
                    putText(frameProcesado, nombreRostro, Point(rostroMostrado.x, std::max(15, rostroMostrado.y - 8)), FONT_HERSHEY_SIMPLEX, 0.6, Scalar(0, 255, 0), 2);
                    escribirLog("VISION cara=" + std::to_string(rostrosAceptados) + " nombre=" + nombreRostro + " ojos=" + std::to_string(ojos.size()) + " x=" + std::to_string(rostroMostrado.x) + " y=" + std::to_string(rostroMostrado.y) + " ancho=" + std::to_string(rostroMostrado.width) + " alto=" + std::to_string(rostroMostrado.height));
                }
                for (int j = 0; j < static_cast<int>(ojos.size()); j++) // Mostrar con recuadros los ojos detectados dentro del rostro.
                {
                    Rect ojoMostrado(rostroMostrado.x + ojos[j].x, rostroMostrado.y + ojos[j].y, ojos[j].width, ojos[j].height);
                    rectangle(frameProcesado, ojoMostrado, Scalar(0, 255, 0), 2);
                }

                // Inicializar CamShift para cada rostro que contiene al menos un ojo, hasta un maximo de cuatro rostros.
                if (usarSeguimientoCamShift && (static_cast<int>(ventanasSeguimiento.size()) < MAX_ROSTROS))
                {
                    Rect ventana;
                    Mat histograma;
                    if (iniciarSeguimientoRostro(frameGris, rostros[i], ventana, histograma))
                    {
                        ventanasSeguimiento.push_back(ventana);
                        histogramasGris.push_back(histograma);
                        nombresSeguimiento.push_back(nombreRostro);
                    }
                }
            }

            seguimientoRostroActivo = usarSeguimientoCamShift && !ventanasSeguimiento.empty();
            contadorFramesSeguimientoRostro = 0;
        }
        else // En los frames intermedios se utiliza CamShift.
        {
            std::vector<Rect> ventanasCamshift;
            std::vector<Mat> histogramasCamshiftGris;
            std::vector<std::string> nombresCamshift;

            for (int i = 0; i < static_cast<int>(ventanasSeguimiento.size()); i++)
            {
                Rect ventana = ventanasSeguimiento[i];
                if (actualizarSeguimientoRostro(frameGris, ventana, histogramasGris[i]))
                {
                    ventanasCamshift.push_back(ventana);
                    histogramasCamshiftGris.push_back(histogramasGris[i]);
                    nombresCamshift.push_back(nombresSeguimiento[i]);
                    Rect ventanaMostrada(ventana.x * 2, ventana.y * 2, ventana.width * 2, ventana.height * 2);
                    rectangle(frameProcesado, ventanaMostrada, Scalar(0, 255, 0), 2); // Verde: region seguida mediante CamShift.
                    if (usarReconocimientoRostros) // Nombre reconocido.
                    {
                        putText(frameProcesado, nombresSeguimiento[i], Point(ventanaMostrada.x, std::max(15, ventanaMostrada.y - 8)), FONT_HERSHEY_SIMPLEX, 0.6, Scalar(0, 255, 0), 2);
                    }
                }
            }

            ventanasSeguimiento = ventanasCamshift;
            histogramasGris = histogramasCamshiftGris;
            nombresSeguimiento = nombresCamshift;
            seguimientoRostroActivo = !ventanasSeguimiento.empty();
            if (seguimientoRostroActivo)
            {
                contadorFramesSeguimientoRostro++;
            }
            else // Si CamShift pierde todas las regiones, se vuelve a ejecutar Haar.
            {
                contadorFramesSeguimientoRostro = 0;
            }
        }

        {
            std::lock_guard<std::mutex> bloqueo(mutexFrames);
            ultimoFrameProcesado = frameProcesado; // Sobreescribir frame con el nuevo resultado.
        }
    }
}
