----------------------------------------------------------------------------------
-- Conecta el sensor CMOS con la FIFO y con el FTDI FT232H.
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL; --contador

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
           JXADC : in STD_LOGIC_VECTOR(7 downto 0));

end TOP;

architecture Behavioral of TOP is

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


signal  CAM_PCLK_edge  : STD_LOGIC;

--aliases puerto JXADC
alias CAM_cable: STD_LOGIC is JXADC(0);
alias CAM_D0: STD_LOGIC is JXADC(1);
alias CAM_D2: STD_LOGIC is JXADC(2);
alias CAM_D4: STD_LOGIC is JXADC(3);
alias CAM_D1: STD_LOGIC is JXADC(5);
alias CAM_D3: STD_LOGIC is JXADC(6);
alias CAM_D5: STD_LOGIC is JXADC(7);


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
signal cam_read_en : std_logic;
signal CAM_Data : STD_LOGIC_VECTOR(7 downto 0);

--señales usadas en camMMCM
signal CAM_CLK1  : STD_LOGIC;
signal CAM_CLK2  : STD_LOGIC;
signal CAM_CLK_locked  : STD_LOGIC;

------------------------------------------
-- SENALES RELACIONADAS CON LA BRAM FIFO
------------------------------------------
--señales usadas en la FIFO
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
signal User_wr_en  : STD_LOGIC;
signal User_rd_en  : STD_LOGIC;
signal User_rdy_flag  : STD_LOGIC;
signal MRST   : STD_LOGIC := '0';

signal synchronizer_RXEn: STD_LOGIC_VECTOR (1 downto 0);
signal FT245_RXEn_sync: STD_LOGIC;

--temporal
signal rd_en_d : std_logic := '0';
signal ready_d : std_logic := '0';
signal lectura_pendiente : std_logic := '0';
signal cam_read_enable : std_logic := '0';
signal cont_dato  : unsigned(7 downto 0) := (others => '0');

begin

    MRST <= btnC;
------------------------------------------
-- CODIGO RELACIONADO CON EL SENSOR CMOS
------------------------------------------

    CAM_Data <= std_logic_vector(cont_dato);--JA(5) & JA(0) & JXADC(7) & JXADC(3) & JXADC(6) & JXADC(2) & JXADC(5) & JXADC(1);
    -- envio contador al FT245 lo mas rapido posible
    process(CAM_XCLK)
    begin
        if rising_edge(CAM_XCLK) then
            if MRST = '1' then
                cont_dato <= (others => '0');
            elsif CAM_HSYNC = '1' then
                cont_dato <= cont_dato + 1;
            end if;
        end if;
    end process;


    --senales de JA que son entradas.
    CAM_D6    <= 'Z'; -- JA(0)
    CAM_HSYNC <= 'Z'; -- JA(2)
    CAM_PCLK  <= 'Z'; -- JA(4)
    CAM_D7    <= 'Z'; -- JA(5)
    CAM_VSYNC <= 'Z'; -- JA(6)
    --senales no usadas en JA
    CAM_SDA <= '1'; -- JA(3)
    CAM_SCL <= '1'; -- JA(7)
    
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
        reset   => MRST, -- i
        pclk_tick   => CAM_PCLK_sync_tick, -- i
        enable   => cam_read_en, -- i
    -- Camera IO ---------------------------
        DIN     => CAM_Data_sync,     -- i[7:0]
        VSYNC   => CAM_VSYNC_sync,     -- i
        HSYNC   => CAM_HSYNC_sync,     -- i
    -- FIFO interface --------------
        DOUT    => FIFO_DIN,     -- o[7:0]
        PUSH    => FIFO_PUSH      -- o
     );

    --tempora. enable de CAM_read se activa si se recibe un comando, por ejemplo x"07".
    process(CLK)
    begin
        if rising_edge(CLK) then
            if MRST = '1' then
                rd_en_d <= '0';
                ready_d <= '0';
                lectura_pendiente <= '0';
                cam_read_enable <= '0';
            else
                rd_en_d <= User_rd_en;
                ready_d <= User_rdy_flag;
                -- FIFO_PUSH deshabilita la captura
                if FIFO_PUSH = '1' then
                    cam_read_enable <= '0';
                end if;
                -- Flanco ascendente de rd_en, comenzo una lectura.
                if rd_en_d = '0' and User_rd_en = '1' then
                    lectura_pendiente <= '1';
                end if;
                -- Flanco ascendente de ready, lectura terminada y se puede analizar el comando recibido.
                if ready_d = '0' and User_rdy_flag = '1' and lectura_pendiente = '1' then
                    lectura_pendiente <= '0';
                    if UserDataOut = x"07" then
                        cam_read_enable <= '1';
                    end if;
                end if;
            end if;
        end if;
    end process;
cam_read_en <= cam_read_enable or SW(0);

-- TEST borrar
    LED(7 downto 0) <= UserDataOut;
    --LED(0) <= FT245_RXEn;
    --LED(1) <= FT245_RXEn_sync;
    --LED(2) <= User_rd_en;
    --LED(3) <= FT245_RDn;
    --LED(4) <= enable_tick;


    LED(8) <= CAM_CLK2; -- CAM_XCLK
    LED(9) <= CAM_PCLK;
    LED(10) <= CAM_HSYNC;
    LED(11) <= CAM_VSYNC;

    LED(12) <= FIFO_PUSH;
    LED(13) <= FIFO_FULL;
    LED(14) <= FIFO_EMPTY;
    LED(15) <= User_wr_en;
    
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
        CLK   => CLK,        -- i
        RST   => MRST,       -- i
    -- FIFO input interface ----------------
        DIN   => FIFO_DIN,   -- i[7:0]
        PUSH  => FIFO_PUSH,  -- i
        FULL  => FIFO_FULL,  -- o
    -- FIFO output interface ---------------
        DOUT  => FIFO_DOUT,  -- o[7:0]
        POP   => FIFO_POP,   -- i
        EMPTY => FIFO_EMPTY  -- o
    );

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
        DIN     => UserDataIn,     -- i[7:0]
        wr_en   => User_wr_en,     -- i
        DOUT    => UserDataOut,    -- o[7:0] -- modo RX
        rd_en   => User_rd_en,     -- i -- modo RX
        ready   => User_rdy_flag,  -- o
    
    -- FT245-like interface --------------
        TXEn    => FT245_TXEn,     -- i
        WRn     => FT245_WRn,      -- o
        RDn     => FT245_RDn,       -- o -- modo RX
        RXEn    => FT245_RXEn,     -- i -- modo RX
        DATA(0) => FT245_D(0),
        DATA(1) => FT245_D(4),
        DATA(2) => FT245_D(1),
        DATA(3) => FT245_D(5),
        DATA(4) => FT245_D(2),
        DATA(5) => FT245_D(6),
        DATA(6) => FT245_D(3),
        DATA(7) => FT245_D(7)
    );

    -- conexionado de la FIFO y del FT245_IF
    UserDataIn <= FIFO_DOUT;
    User_wr_en <= FIFO_POP;
    FIFO_POP <= User_rdy_flag and not FIFO_EMPTY;
    -- si FT245_RXEn baja, se habilita rd_en para leer el byte disponible.
    process begin
        wait until rising_edge(clk);
        synchronizer_RXEn <= FT245_RXEn & synchronizer_RXEn(1);
    end process;
    FT245_RXEn_sync <= synchronizer_RXEn(0);
    User_rd_en <= not FT245_RXEn_sync;

end Behavioral;
