----------------------------------------------------------------------------------
-- Conecta el sensor CMOS con la FIFO y con el FTDI FT232H.
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL; --contador, borrar

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;


entity TOP is
    Port ( sw : in STD_LOGIC_VECTOR (15 downto 0);
           btnC, btnU, btnL, btnR, btnD : in STD_LOGIC;
           led : out STD_LOGIC_VECTOR (15 downto 0);
           seg : out STD_LOGIC_VECTOR (6 downto 0);
           dp  : out STD_LOGIC;
           an : out STD_LOGIC_VECTOR (3 downto 0);
           -- FT245
           clk : in STD_LOGIC;
           JA : inout STD_LOGIC_VECTOR(7 downto 0);
           JB : inout STD_LOGIC_VECTOR(7 downto 0); -- DATA de FTDI_IF es io.
           JC : inout STD_LOGIC_VECTOR(7 downto 0);
           JXADC : inout STD_LOGIC_VECTOR(7 downto 0));

end TOP;

architecture Behavioral of TOP is

------------------------------------------
-- SENALES RELACIONADAS CON EL MODULO CTRL
------------------------------------------
--senales del modulo de control
signal Ctrl_reset : std_logic;

signal CtrlCAM_read_reset : std_logic;
signal CtrlCAM_read_en : std_logic;
signal CtrlCAM_read_color : std_logic;
signal CtrlCAM_pclk_tick : std_logic;

signal CtrlFIFO_reset : std_logic;
signal CtrlFIFO_PUSH : std_logic;
signal CtrlFIFO_POP : std_logic;
signal CtrlFIFO_EMPTY : std_logic;

signal CtrlFTDI_IF_en : std_logic;
signal CtrlFTDI_IF_ready : std_logic;
signal CtrlFTDI_IF_wrn_rd : std_logic;
signal CtrlFTDI_IF_DOUT : std_logic_vector(7 downto 0);
signal CtrlFTDI_IF_RXEn : std_logic;
signal CtrlFTDI_IF_TXEn : std_logic;


------------------------------------------
-- SENALES RELACIONADAS CON EL SENSOR CMOS
------------------------------------------

--aliases puerto JA
alias CAM_D6: STD_LOGIC is JA(0);
alias CAM_XCLK: STD_LOGIC is JA(1);
alias CAM_HSYNC: STD_LOGIC is JA(2);
alias CAM_SDA: STD_LOGIC is JA(3);
alias CAM_PCLK: STD_LOGIC is JA(4);
alias CAM_D7: STD_LOGIC is JA(5);
alias CAM_VSYNC: STD_LOGIC is JA(6);
alias CAM_SCL: STD_LOGIC is JA(7);

--aliases puerto JXADC
alias CAM_cable: STD_LOGIC is JXADC(0); --reset del sensor CMOS
alias CAM_D0: STD_LOGIC is JXADC(1);
alias CAM_D2: STD_LOGIC is JXADC(2);
alias CAM_D4: STD_LOGIC is JXADC(3);
alias CAM_D1: STD_LOGIC is JXADC(5);
alias CAM_D3: STD_LOGIC is JXADC(6);
alias CAM_D5: STD_LOGIC is JXADC(7);

signal CAM_Data : STD_LOGIC_VECTOR(7 downto 0);


-- señales provenientes del sensor. Sincronizadas.
signal synchronizer_hsync : std_logic_vector(1 downto 0);
signal synchronizer_vsync : std_logic_vector(1 downto 0);
signal synchronizer_pclk  : std_logic_vector(1 downto 0);
signal synchronizer_data  : std_logic_vector(15 downto 0); -- 2FF para cada bit del bus de 8 senales.
signal CAM_HSYNC_sync  : STD_LOGIC;
signal CAM_VSYNC_sync  : STD_LOGIC;
signal CAM_PCLK_sync  : STD_LOGIC;
signal CAM_Data_sync  : STD_LOGIC_VECTOR(7 downto 0);
-- señal PCLK sincronizada y de duracion 10ns.
signal CAM_PCLK_sync_tick  : STD_LOGIC;

-- señales usadas por el interfaz cam_read.
signal CAM_read_reset : std_logic;
signal CAM_read_en : std_logic;
signal CAM_read_color : std_logic;

--señales usadas en camMMCM
signal CAM_CLK1  : STD_LOGIC;
signal CAM_CLK2  : STD_LOGIC;
signal CAM_CLK_locked  : STD_LOGIC;

------------------------------------------
-- SENALES RELACIONADAS CON LA BRAM FIFO
------------------------------------------
--señales usadas en la FIFO
signal FIFO_reset : STD_LOGIC;
signal FIFO_DIN : STD_LOGIC_VECTOR(7 downto 0);
signal FIFO_PUSH : STD_LOGIC;
signal FIFO_FULL : STD_LOGIC;
signal FIFO_DOUT : STD_LOGIC_VECTOR(7 downto 0);
signal FIFO_POP : STD_LOGIC;
signal FIFO_EMPTY : STD_LOGIC;


------------------------------------------
-- SENALES RELACIONADAS CON EL FTDI FT232H
------------------------------------------
--aliases puerto JC
alias FT245_D: STD_LOGIC_VECTOR(7 downto 0) is JB;
alias FT245_RXEn : STD_LOGIC is JC(0); --JC1, K17 , -i
alias FT245_RDn  : STD_LOGIC is JC(1); --JC2, M18 , -o
alias FT245_SIWUn  : STD_LOGIC is JC(2); --JC3, N17 , -o
alias FT245_OEn  : STD_LOGIC is JC(3); --JC4, P18 , -o
alias FT245_TXEn : STD_LOGIC is JC(4); --JC7, L17 , -i
alias FT245_WRn  : STD_LOGIC is JC(5); --JC8, M19 , -o
alias FT245_CLKOUT  : STD_LOGIC is JC(6); --JC9, P17 , -i
alias PWRSAVn  : STD_LOGIC is JC(7); --JC10, R18 , -o

--señales usadas en FT245_IF, lado FPGA
signal UserDataIn  : STD_LOGIC_VECTOR(7 downto 0);
signal UserDataOut  : STD_LOGIC_VECTOR(7 downto 0);
signal User_wrn_rd  : STD_LOGIC;
signal User_en  : STD_LOGIC;
signal User_rdy_flag  : STD_LOGIC;
signal MRST   : STD_LOGIC;

signal synchronizer_RXEn: STD_LOGIC_VECTOR (1 downto 0);
signal FT245_RXEn_sync: STD_LOGIC;
signal synchronizer_TXEn: STD_LOGIC_VECTOR (1 downto 0);
signal FT245_TXEn_sync: STD_LOGIC;

------------------------------------------
-- SENALES CONVERSOR HEX - 7 SEGMENTOS
------------------------------------------
signal DIGIT_0_HEX : STD_LOGIC_VECTOR(3 downto 0);
signal DIGIT_1_HEX : STD_LOGIC_VECTOR(3 downto 0);
signal DIGIT_2_HEX : STD_LOGIC_VECTOR(3 downto 0);
signal DIGIT_3_HEX : STD_LOGIC_VECTOR(3 downto 0);
signal CAT_7_BIT_VECTOR : STD_LOGIC_VECTOR(6 downto 0);
signal DIGIT_SELECTED_HEX : STD_LOGIC_VECTOR(3 downto 0);
signal contador_display : unsigned(17 downto 0) := (others => '0');
signal numero_display : STD_LOGIC_VECTOR(1 downto 0);
-- senales para calcular los fps entregados por el sensor CMOS.
signal contador_segundo : integer range 0 to 99_999_999 := 0; --  ciclos en un segundo a 100MHz.
signal contador_frames_cmos : integer range 0 to 99 := 0;
signal fps_cmos : integer range 0 to 99 := 0; -- dos BCDs usados.
signal vsync_anterior : STD_LOGIC := '0'; -- detecta el flanco de subida de CAM_VSYNC_sync .
-- senales para calcular los fps entregados al dispositivo FTDI.
signal contador_frames_ftdi : integer range 0 to 99 := 0;
signal fps_ftdi : integer range 0 to 99 := 0;
signal cam_read_en_anterior : STD_LOGIC := '0';
-- senales para indicar el uso del sensor CMOS y dispositivo FTDI en LED15 y LED0
signal contador_parpadeo_cmos : unsigned(3 downto 0) := (others => '0'); -- Se estiman 15 FPS, asi se crea una senal aproximadamente simetrica.
signal contador_parpadeo_ftdi : unsigned(3 downto 0) := (others => '0');

begin

MRST <= Ctrl_reset or btnC;

------------------------------------------
-- CODIGO RELACIONADO CON EL MODULO CTRL
------------------------------------------

    CTRL_inst: entity work.CONTROL
    port map (
        clk     => CLK, -- i
        reset   => MRST, -- i
        reset_out => Ctrl_reset, -- o
        
    -- CAM_read --------------------------
        CAM_read_reset => CtrlCAM_read_reset,-- o
        CAM_read_en => CtrlCAM_read_en,-- o
        CAM_read_color => CtrlCAM_read_color,-- o
        CAM_pclk_tick => CtrlCAM_pclk_tick,-- i
        
    -- FIFO interface -------------------
        FIFO_reset => CtrlFIFO_reset, -- o
        FIFO_PUSH => CtrlFIFO_PUSH, -- i
        FIFO_POP => CtrlFIFO_POP, -- o
        FIFO_EMPTY => CtrlFIFO_EMPTY, -- i
        
    -- FTDI_IF interface ----------------
        FTDI_IF_en => CtrlFTDI_IF_en, -- o
        FTDI_IF_ready => CtrlFTDI_IF_ready, -- i
        FTDI_IF_wrn_rd => CtrlFTDI_IF_wrn_rd, -- o
        FTDI_IF_DOUT => CtrlFTDI_IF_DOUT, -- i(7:0)
        FTDI_IF_RXEn => CtrlFTDI_IF_RXEn, -- i
        FTDI_IF_TXEn => CtrlFTDI_IF_TXEn -- i
    );

    CtrlCAM_pclk_tick <= CAM_PCLK_sync_tick;

    CtrlFIFO_PUSH <= FIFO_PUSH;
    CtrlFIFO_EMPTY <= FIFO_EMPTY;

    CtrlFTDI_IF_ready <= User_rdy_flag;
    CtrlFTDI_IF_DOUT <= UserDataOut;
    CtrlFTDI_IF_RXEn <= FT245_RXEn_sync;
    CtrlFTDI_IF_TXEn <= FT245_TXEn_sync;
    

------------------------------------------
-- CODIGO RELACIONADO CON EL SENSOR CMOS
------------------------------------------

    CAM_Data <= JA(5) & JA(0) & JXADC(7) & JXADC(3) & JXADC(6) & JXADC(2) & JXADC(5) & JXADC(1);
    CAM_cable <= CAM_CLK_locked; -- reset del sensor CMOS, activo en alto.

    --senales de JA que son entradas.
    CAM_D6    <= 'Z'; -- JA(0)
    CAM_HSYNC <= 'Z'; -- JA(2)
    CAM_PCLK  <= 'Z'; -- JA(4)
    CAM_D7    <= 'Z'; -- JA(5)
    CAM_VSYNC <= 'Z'; -- JA(6)
    --senales no usadas en JA
    CAM_SDA <= '1'; -- JA(3)
    CAM_SCL <= '1'; -- JA(7)
    --senales de JXADC que son entradas.
    CAM_D0 <= 'Z'; -- JXADC(1)
    CAM_D1 <= 'Z'; -- JXADC(5)
    CAM_D2 <= 'Z'; -- JXADC(2)
    CAM_D3 <= 'Z'; -- JXADC(6)
    CAM_D4 <= 'Z'; -- JXADC(3)
    CAM_D5 <= 'Z'; -- JXADC(7)

    --reloj de 12Mhz para CAM_XCLK
    camMMCM: entity WORK.clk_wiz_0
    port map (
        clk_in1 => CLK,
        reset => MRST,
        clk_out1 => CAM_CLK1,
        clk_out2 => CAM_CLK2,
        locked => CAM_CLK_locked
    );
    CAM_XCLK <= CAM_CLK2;

    -- se sincronizan las senales provenientes del sensor CMOS: PCLK, VSYNC, HSYNC y DATA(7 downto 0).
    process
    begin
        wait until rising_edge(clk);
        synchronizer_hsync <= CAM_HSYNC & synchronizer_hsync(1);
        synchronizer_vsync <= CAM_VSYNC & synchronizer_vsync(1);
        synchronizer_pclk  <= CAM_PCLK  & synchronizer_pclk(1);
        synchronizer_data <= CAM_Data & synchronizer_data(15 downto 8);
    end process;

    CAM_HSYNC_sync <= synchronizer_hsync(0);
    CAM_VSYNC_sync <= synchronizer_vsync(0);
    CAM_PCLK_sync  <= synchronizer_pclk(0);
    -- std_logic_vector(cont_dato);
    CAM_Data_sync  <= synchronizer_data(7 downto 0);

    -- crear senal que se activa un solo flanco de reloj al subir PCLK_sync.
    PCLK_EDGE: entity work.edge_detect
    port map (
        clk   => clk,
        reset => MRST,
        level => CAM_PCLK_sync,
        tick  => CAM_PCLK_sync_tick
    );
    
-- ===============================
--    INSTANCE TEMPLATE
-- ===============================
    cam_read_inst: entity work.cam_read
    port map (
        clk     => CLK, -- i
        reset   => CAM_read_reset, -- i
        pclk_tick   => CAM_PCLK_sync_tick, -- i
        enable   => CAM_read_en, -- i
        color   => CAM_read_color, -- i
    -- Camera IO ---------------------------
        DIN     => CAM_Data_sync,     -- i[7:0]
        VSYNC   => CAM_VSYNC_sync,     -- i
        HSYNC   => CAM_HSYNC_sync,     -- i
    -- FIFO interface --------------
        DOUT    => FIFO_DIN,     -- o[7:0]
        PUSH    => FIFO_PUSH      -- o
     );

    CAM_read_reset <= CtrlCAM_read_reset or MRST;
    CAM_read_en <= CtrlCAM_read_en or SW(0);
    CAM_read_color <= CtrlCAM_read_color;


-- DEBUG
--    LED(4) <= CAM_CLK2; -- CAM_XCLK
--    LED(5) <= CAM_PCLK;
--    LED(6) <= CAM_HSYNC;
--    LED(7) <= CAM_VSYNC;

--    LED(9) <= FIFO_PUSH;
--    LED(10) <= FIFO_POP;
--    LED(11) <= FIFO_EMPTY;
--    LED(12) <= FIFO_FULL;
    
------------------------------------------
-- CODIGO RELACIONADO CON LA FIFO BRAM
------------------------------------------

--B = anchura del Bus de direcciones.
--W = anchura de los buses de datos DIN y DOUT.
-- ===============================
--    INSTANCE TEMPLATE
-- ===============================
    FIFO_inst : entity work.FIFO
    port map (
        CLK   => CLK, -- i
        RST   => FIFO_reset, -- i
    -- FIFO input interface ----------------
        DIN   => FIFO_DIN,   -- i[7:0]
        PUSH  => FIFO_PUSH,  -- i
        FULL  => FIFO_FULL,  -- o
    -- FIFO output interface ---------------
        DOUT  => FIFO_DOUT,  -- o[7:0]
        POP   => FIFO_POP,   -- i
        EMPTY => FIFO_EMPTY  -- o
    );

    FIFO_reset <= CtrlFIFO_reset or MRST;
    FIFO_POP <= CtrlFIFO_POP;

------------------------------------------
-- CODIGO RELACIONADO CON EL FTDI FT232H
------------------------------------------
    --senales de JC que son entradas.
    FT245_RXEn   <= 'Z'; -- JC(0)
    FT245_TXEn   <= 'Z'; -- JC(4)
    FT245_CLKOUT <= 'Z'; -- JC(6)
    --senales de JC no utilizadas.
    FT245_SIWUn <= '1'; -- JC(2), no usado.
    FT245_OEn   <= '1'; -- JC(3), no usado, solo para modo sincrono.
    PWRSAVn     <= '1'; -- JC(7), no usado.

--instancia del controlador FT245
-- ===============================
--    INSTANCE TEMPLATE
-- ===============================
    FT245_inst: entity work.FT245_IF
    port map (
        clk     => CLK, -- i
        reset   => MRST, -- i
    
    -- User IO ---------------------------
        DIN     => UserDataIn, -- i[7:0]
        wrn_rd   => User_wrn_rd, -- i
        DOUT    => UserDataOut, -- o[7:0] -- modo RX
        enable   => User_en, -- i
        ready   => User_rdy_flag, -- o
    
    -- FT245-like interface --------------
        TXEn    => FT245_TXEn, -- i, internmaente sincronizada.
        WRn     => FT245_WRn, -- o, modo TX.
        RDn     => FT245_RDn, -- o, modo RX.
        RXEn    => FT245_RXEn, -- i, internamente sincronizada.
        DATA(0) => FT245_D(0),
        DATA(1) => FT245_D(4),
        DATA(2) => FT245_D(1),
        DATA(3) => FT245_D(5),
        DATA(4) => FT245_D(2),
        DATA(5) => FT245_D(6),
        DATA(6) => FT245_D(3),
        DATA(7) => FT245_D(7)
    );

    -- conexionado del modulo de control y el FT245_IF
    User_wrn_rd <= CtrlFTDI_IF_wrn_rd;
    User_en <= CtrlFTDI_IF_en;
    -- conexionado de la FIFO y el FT245_IF
    UserDataIn <= FIFO_DOUT;
    -- conexionado del FT245_IF con JB y JC.
    -- sincronizacion de senales de entrada TXEn y RXEn.
    process begin
        wait until rising_edge(clk);
        synchronizer_RXEn <= FT245_RXEn & synchronizer_RXEn(1);
        synchronizer_TXEn <= FT245_TXEn & synchronizer_TXEn(1);
    end process;
    FT245_RXEn_sync <= synchronizer_RXEn(0);
    FT245_TXEn_sync <= synchronizer_TXEn(0);



------------------------------------------
-- CODIGO RELACIONADO HEX - 7 SEGMENTOS
------------------------------------------

--multiplexor 4 a 1, selecciona uno de los 4 vectores DIGIT_X_HEX. No hay prioridad entre las entradas.
    with numero_display select
    DIGIT_SELECTED_HEX <= DIGIT_0_HEX when "00",
        DIGIT_1_HEX when "01",
        DIGIT_2_HEX when "10",
        DIGIT_3_HEX when "11",
        (others => '0') when others;

-- modulo combinacional: conversor de 4 bits a 7.
    process (DIGIT_SELECTED_HEX)
    begin
        case DIGIT_SELECTED_HEX is
        when "0000" => CAT_7_BIT_VECTOR <= "1000000"; -- al tener el digito anodo comun, la señal requerida para activar/desactivar el segmento esta invertido.
        when "0001" => CAT_7_BIT_VECTOR <= "1111001";
        when "0010" => CAT_7_BIT_VECTOR <= "0100100";
        when "0011" => CAT_7_BIT_VECTOR <= "0110000";
        when "0100" => CAT_7_BIT_VECTOR <= "0011001";
        when "0101" => CAT_7_BIT_VECTOR <= "0010010";
        when "0110" => CAT_7_BIT_VECTOR <= "0000010";
        when "0111" => CAT_7_BIT_VECTOR <= "1111000";
        when "1000" => CAT_7_BIT_VECTOR <= "0000000";
        when "1001" => CAT_7_BIT_VECTOR <= "0010000";
        when "1010" => CAT_7_BIT_VECTOR <= "0001000";
        when "1011" => CAT_7_BIT_VECTOR <= "0000011";
        when "1100" => CAT_7_BIT_VECTOR <= "1000110";
        when "1101" => CAT_7_BIT_VECTOR <= "0100001";
        when "1110" => CAT_7_BIT_VECTOR <= "0000110";
        when "1111" => CAT_7_BIT_VECTOR <= "0001110";
        when others => CAT_7_BIT_VECTOR <= "1111111";   -- todas las combinaciones posibles estan cubiertas.
        end case;
    end process;

-- Contador para multiplexar los cuatro displays. 
    process (clk, MRST)
    begin
        if MRST = '1' then
            contador_display <= (others => '0');
        elsif rising_edge(clk) then
            contador_display <= contador_display + 1;
        end if;
    end process;
    
-- Seleccion del display mediante los bits superiores.
    numero_display <= std_logic_vector(contador_display(17 downto 16));
    
-- Los anodos de la Basys 3 son activos a nivel bajo.
    with numero_display select
        an <= "1110" when "00",
            "1101" when "01",
            "1011" when "10",
            "0111" when "11",
            "1111" when others;

-- Calcular fps desde el sensor CMOS y hacia el controlador FTDI.
    process (clk)
    begin
        if rising_edge(clk) then
            vsync_anterior <= CAM_VSYNC_sync;
            cam_read_en_anterior <= CtrlCAM_read_en;
            if contador_segundo = 99_999_999 then
                contador_segundo <= 0;
                fps_cmos <= contador_frames_cmos; -- FPS desde el sensor CMOS.
                contador_frames_cmos <= 0;
                fps_ftdi <= contador_frames_ftdi; -- FPS hacia el dispositivo FTDI.
                contador_frames_ftdi <= 0;
            else
                contador_segundo <= contador_segundo + 1;
                if CAM_VSYNC_sync = '1' and vsync_anterior = '0' then -- flanco de subida, nuevo frame desde el sensor CMOS.
                    contador_frames_cmos <= contador_frames_cmos + 1;
                    contador_parpadeo_cmos <= contador_parpadeo_cmos + 1;
                end if;
                if CtrlCAM_read_en = '1' and cam_read_en_anterior = '0' then -- flanco de subida, nueva peticion de lectura de un frame desde FTDI.
                    contador_frames_ftdi <= contador_frames_ftdi + 1;
                    contador_parpadeo_ftdi <= contador_parpadeo_ftdi + 1;
                end if;
            end if;
        end if;
    end process;

    DIGIT_0_HEX <= std_logic_vector(to_unsigned(fps_cmos mod 10, 4)); -- Digito menos significativo fps CMOS.
    DIGIT_1_HEX <= std_logic_vector(to_unsigned(fps_cmos / 10, 4)); -- Decenas fps CMOS.
    DIGIT_2_HEX <= std_logic_vector(to_unsigned(fps_ftdi mod 10, 4)); -- Digito menos significativo fps FTDI.
    DIGIT_3_HEX <= std_logic_vector(to_unsigned(fps_ftdi / 10, 4)); -- Decenas fps FTDI.

    seg <= CAT_7_BIT_VECTOR;
    dp <= '1'; -- activo a nivel bajo.

    LED(15) <= not contador_parpadeo_cmos(3); -- A unos 15fps, la frecuencia de parpadeo es 15/16, 1Hz aproximadamente.
    LED(0) <= not contador_parpadeo_ftdi(3);

end Behavioral;
