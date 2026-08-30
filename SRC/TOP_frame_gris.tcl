#############################################################################
# Validacion modulo TOP.vhd.
# Plantilla basica para script de simulacion.
#############################################################################

# reinicia la simulacion y el instante de simulacion vuelve a 0ns
restart
remove_wave [get_waves -r *]
# Entradas generales.
add_wave {{/TOP/CLK}}
add_wave {{/TOP/MRST}}
# Modulo CONTROL.
add_wave {{/TOP/CTRL_inst/state_reg}}
add_wave {{/TOP/CTRL_inst/CAM_read_en}}
add_wave {{/TOP/CTRL_inst/CAM_read_color}}
add_wave {{/TOP/CTRL_inst/FIFO_POP}}
add_wave {{/TOP/CTRL_inst/FTDI_IF_en}}
add_wave {{/TOP/CTRL_inst/FTDI_IF_wrn_rd}}
# Modulo CAM_READ.
add_wave {{/TOP/JA(4)}} -name PCLK ext ;# CAM_PCLK externo.
add_wave {{/TOP/JA(6)}} -name VSYNC ext ;# CAM_VSYNC externo.
add_wave {{/TOP/JA(2)}} -name HSYNC ext ;# CAM_HSYNC externo.
add_wave {{/TOP/CAM_Data}} -radix hex ;# Senales externas.
add_wave {{/TOP/CAM_Data_sync}} -radix hex
add_wave {{/TOP/CAM_PCLK_sync_tick}}
add_wave {{/TOP/cam_read_inst/state_reg}}
add_wave {{/TOP/cam_read_inst/DOUT}} -radix hex
add_wave {{/TOP/cam_read_inst/PUSH}}
# FIFO.
add_wave {{/TOP/FIFO_inst/DIN}} -radix hex
add_wave {{/TOP/FIFO_inst/PUSH}}
add_wave {{/TOP/FIFO_inst/FULL}}
add_wave {{/TOP/FIFO_inst/POP}}
add_wave {{/TOP/FIFO_inst/DOUT}} -radix hex
add_wave {{/TOP/FIFO_inst/EMPTY}}
add_wave {{/TOP/FIFO_inst/contador}} -radix unsigned
# FTDI_IF.
add_wave {{/TOP/FT245_inst/RXEn}}
add_wave {{/TOP/FT245_inst/RDn}}
add_wave {{/TOP/FT245_inst/TXEn}}
add_wave {{/TOP/FT245_inst/WRn}}
add_wave {{/TOP/FT245_inst/DATA}} -radix hex
add_wave {{/TOP/FT245_inst/DOUT}} -radix hex
add_wave {{/TOP/FT245_inst/state_reg}}
add_wave {{/TOP/FT245_inst/ready}}

# Aplicacion de estimulos basicos.
# Reloj principal de 100 MHz, periodo de 10 ns.
add_force {/TOP/CLK} -radix bin {0 0ns} {1 5ns} -repeat_every 10ns
# PCLK de la camara de aproximadamente 12,5 MHz, periodo de 80 ns.
add_force {/TOP/JA(4)} -radix bin {0 0ns} {1 40ns} -repeat_every 80ns
# Pulsadores y switches inactivos.
add_force {/TOP/SW} -radix hex {0000 0ns}
add_force {/TOP/btnC} -radix bin {1 0ns} {0 100ns}
add_force {/TOP/btnU} -radix bin {0 0ns}
add_force {/TOP/btnL} -radix bin {0 0ns}
add_force {/TOP/btnR} -radix bin {0 0ns}
add_force {/TOP/btnD} -radix bin {0 0ns}
# Entradas de la camara inicialmente inactivas.
add_force {/TOP/JA(6)} -radix bin {0 0ns} ;# CAM_VSYNC.
add_force {/TOP/JA(2)} -radix bin {0 0ns} ;# CAM_HSYNC.
add_force {/TOP/CAM_Data} -radix hex {00 0ns}
# Dispositivo FTDI no indica que esta disponible.
add_force {/TOP/JC(0)} -radix bin {1 0ns} ;# RXEn
add_force {/TOP/JC(4)} -radix bin {1 0ns} ;# TXEn
run 100 ns

#############################################################################
# TEST. RECEPCION COMANDO DESDE EL FTDI. FRAME EN BN.
#############################################################################

# FTDI tiene un comando disponible, baja RXEn.
add_force {/TOP/JC(0)} -radix bin {0 0ns}
# FTDI admite recibir comandos, baja TXEn.
add_force {/TOP/JC(4)} -radix bin {0 0ns}

# RDn baja a los 65ns y sube a los 95ns. Se coloca el comando 01 en el bus de datos del FTDI con un margen de 10ns (min 1ns, max 14ns).
# Para este valor la permutacion de los pines de JB no cambia el resultado.
add_force {/TOP/JB} -radix hex {00 0ns} {01 75ns} {00 105ns}
# FTDI sube RXEn 10ns (min 1ns, max 14ns) tras subir RDn. Ya no vuelve a indicar dato disponible para leer.
add_force {/TOP/JC(0)} -radix bin {0 0ns} {1 105ns}
run 120 ns

# 220ns
# Se libera JB o DATA pues la simulacion va a escribir en el bus.
remove_forces {/TOP/JB}
# Se deja tiempo para que CONTROL lea el comando y active CAM_READ (35ns), manteniendolo hasta la llegada del siguiente pclk_tick (95ns).
run 100 ns

#############################################################################
# TEST. CAM_READ COMIENZA A LEER UN FRAME.
#############################################################################
# 320ns
# CAM_READ pasa al estado en espera wait_frame_start.
run 80ns 
# LLega desde el sensor un nuevo frame. 
add_force {/TOP/JA(6)} -radix bin {1 0ns} ;# CAM_VSYNC activo 6 ciclos PCLK, cada uno de 80ns.
run 480 ns
# Se activa HSYNC y con ello los bytes utiles del sensor CMOS.
# Los datos tienen formato Cb Y0 Cr Y1 Cb Y2 Cr Y3.
# En blanco y negro CAM_READ debe guardar solo los bytes de luminancia YX (11, 22, 33 y 44).
add_force {/TOP/JA(2)} -radix bin {1 0ns} ;# CAM_HSYNC
add_force {/TOP/CAM_Data} -radix hex {10 0ns} ;# Cb
run 80 ns
add_force {/TOP/CAM_Data} -radix hex {11 0ns} ;# Y0
run 80 ns
add_force {/TOP/CAM_Data} -radix hex {20 0ns} ;# Cr
run 80 ns
add_force {/TOP/CAM_Data} -radix hex {22 0ns} ;# Y1
run 80 ns
add_force {/TOP/CAM_Data} -radix hex {30 0ns} ;# Cb
run 80 ns
add_force {/TOP/CAM_Data} -radix hex {33 0ns} ;# Y2
run 80 ns
add_force {/TOP/CAM_Data} -radix hex {40 0ns} ;# Cr
run 80 ns
add_force {/TOP/CAM_Data} -radix hex {44 0ns} ;# Y3
run 80 ns

# Blanking entre la primera y la segunda linea.
add_force {/TOP/JA(2)} -radix bin {0 0ns} ;# CAM_HSYNC
add_force {/TOP/CAM_Data} -radix hex {FF 0ns} ;# Deben descartarse.
run 320 ns

# Comienza la segunda linea.
# En blanco y negro CAM_READ debe guardar solo los bytes de luminancia YX (55, 66, 77 y 88).
add_force {/TOP/JA(2)} -radix bin {1 0ns} ;# CAM_HSYNC
add_force {/TOP/CAM_Data} -radix hex {50 0ns} ;# Cb
run 80 ns
add_force {/TOP/CAM_Data} -radix hex {55 0ns} ;# Y0
run 80 ns
add_force {/TOP/CAM_Data} -radix hex {60 0ns} ;# Cr
run 80 ns
add_force {/TOP/CAM_Data} -radix hex {66 0ns} ;# Y1
run 80 ns
add_force {/TOP/CAM_Data} -radix hex {70 0ns} ;# Cb
run 80 ns
add_force {/TOP/CAM_Data} -radix hex {77 0ns} ;# Y2
run 80 ns
add_force {/TOP/CAM_Data} -radix hex {80 0ns} ;# Cr
run 80 ns
add_force {/TOP/CAM_Data} -radix hex {88 0ns} ;# Y3
run 80 ns

# Tras la segunda y ultima linea, primero baja HSYNC 6 ciclos de PCLK.
add_force {/TOP/JA(2)} -radix bin {0 0ns} ;# CAM_HSYNC
add_force {/TOP/CAM_Data} -radix hex {00 0ns}
run 480 ns
# Termina el frame bajando VSYNC.
add_force {/TOP/JA(6)} -radix bin {0 0ns} ;# CAM_VSYNC
# LA FIFO deba vaciarse complemtamente.
run 500 ns

