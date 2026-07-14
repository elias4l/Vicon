----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Emilio Elias Sujar Overbury
-- 
-- Create Date: 07.01.2025 21:53:43
-- Design Name: Ejercicio primero.
-- Module Name: TOP - Behavioral
-- Project Name: Primero.
-- Target Devices: Artix 7 xc7a35t
-- Tool Versions: Vivado 2019.1
-- Description: This is an exercise project. With the eight LSB switches you control the 7-segments cathodes. With the buttons (except BTNC) you control the 7-segments anodes. Each LED is controlled by one switch or one button.
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
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
           JB : out STD_LOGIC_VECTOR(7 downto 0);
           JC : inout STD_LOGIC_VECTOR(7 downto 0);
           JXADC : in STD_LOGIC_VECTOR(7 downto 0));

end TOP;

architecture Behavioral of TOP is
--aliases puerto JC
alias FT245_D: STD_LOGIC_VECTOR(7 downto 0) is JB;
alias FT245_TXEn : STD_LOGIC is JC(4); --JC7, L17 (desde 1)
alias FT245_WRn  : STD_LOGIC is JC(5); --JC8, M19 (desde 1)
alias FT245_RDn  : STD_LOGIC is JC(1); --JC2, M18 , -o
alias FT245_OEn  : STD_LOGIC is JC(3); --JC4, P18, -o
alias FT245_SIWUn  : STD_LOGIC is JC(2);

--aliases puerto JA
--alias CAM_D6: STD_LOGIC is JA(0);
--alias CAM_XCLK: STD_LOGIC is JA(1);
--alias CAM_HSYNC: STD_LOGIC is JA(2);
--alias CAM_SDA: STD_LOGIC is JA(3);
--alias CAM_PCLK: STD_LOGIC is JA(4);
--alias CAM_D7: STD_LOGIC is JA(5);
--alias CAM_VSYNC: STD_LOGIC is JA(6);
--alias CAM_SCL: STD_LOGIC is JA(7);

signal  CAM_PCLK  : STD_LOGIC;
signal  CAM_PCLK_edge  : STD_LOGIC;

--aliases puerto JXADC
--alias CAM_cable: STD_LOGIC is JXADC(0);
--alias CAM_D0: STD_LOGIC is JXADC(1);
--alias CAM_D2: STD_LOGIC is JXADC(2);
--alias CAM_D4: STD_LOGIC is JXADC(3);
--alias CAM_D1: STD_LOGIC is JXADC(5);
--alias CAM_D3: STD_LOGIC is JXADC(6);
--alias CAM_D5: STD_LOGIC is JXADC(7);

signal  CAM_Data  : STD_LOGIC_VECTOR(7 downto 0);
signal CAM_HSYNC  : STD_LOGIC;
signal CAM_VSYNC  : STD_LOGIC;

--señales usadas en camMMCM
signal CAM_CLK1  : STD_LOGIC;
signal CAM_CLK2  : STD_LOGIC;
signal CAM_CLK_locked  : STD_LOGIC;

--señales usadas en FT245_IF
signal UserDataIn  : STD_LOGIC_VECTOR(7 downto 0);
signal User_wr_en  : STD_LOGIC;
signal User_rdy_flag  : STD_LOGIC;
signal FT245_TXEn_s   : STD_LOGIC;
signal FT245_WRn_s    : STD_LOGIC;
signal FT245_D_s   : STD_LOGIC_VECTOR(7 downto 0);
signal MRST   : STD_LOGIC := '0';


-- contador, borrar
signal cont_freq  : unsigned(32 downto 0) := (others => '0');
signal cont_dato  : unsigned(7 downto 0) := (others => '0');

--test borrar
signal  CAM_div_22  : STD_LOGIC;


    signal cam_div : unsigned(23 downto 0) := (others => '0'); --borrar, LED15
begin
    --alta impedancia para senales de entrada o no usadas en JA
--    JA(0) <= 'Z'; -- CAM_D6
--    JA(2) <= 'Z'; -- CAM_HSYNC
--    JA(4) <= 'Z'; -- CAM_PCLK
--    JA(5) <= 'Z'; -- CAM_D7
--    JA(6) <= 'Z'; -- CAM_VSYNC
    JA(3) <= '1'; -- SDA
    JA(7) <= '1'; -- SCL
    
    --reloj de 12Mhz para CAM_XCLK
    camMMCM: entity WORK.clk_wiz_0
    port map (
        clk_in1 => CLK,
        reset => MRST,
        clk_out1 => CAM_CLK1,
        clk_out2 => CAM_CLK2,
        locked => CAM_CLK_locked
    );
    JA(1) <= CAM_CLK2;
    
    --borrar, LED 15 muestra el reloj 12MHz
    process(CAM_CLK2)
    begin
        if rising_edge(CAM_CLK2) then
            cam_div <= cam_div + 1;
        end if;
    end process;
    LED(15) <= cam_div(22);
    
    --borrar, crear tick con flanco de subida de CAM_PCLK
    edge_CAM_PCLK: entity work.edge_detect
    port map (
        clk   => CLK,
        reset => MRST,
        level => CAM_PCLK,
        tick  => CAM_PCLK_edge
    );
    CAM_PCLK <= JA(4);
    User_wr_en <= CAM_PCLK_edge;
    
    

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
        ready   => User_rdy_flag,  -- o
    
    -- FT245-like interface --------------
        TXEn    => FT245_TXEn_s,     -- i
        WRn     => FT245_WRn_s,      -- o
        DATA    => FT245_D_s         -- o[7:0]
    );
    
    FT245_D <= FT245_D_s;
    FT245_WRn <= FT245_WRn_s;
    FT245_TXEn_s <= FT245_TXEn;
    FT245_SIWUn <= not btnL;

-- directly connect input signals with output signals
    LED(14) <= FT245_WRn_s;
    LED(13) <= FT245_TXEn_s;
    
    LED(12) <= User_wr_en;
    LED(11) <= User_rdy_flag;
    LED(10 downto 0) <= SW(10 downto 0);
--    CAT <= SW(7 downto 0);
    seg <= FT245_D_s(6 downto 0);
    dp  <= FT245_D_s(7);
    AN <= btnL & btnD & btnR & btnU;
    MRST <= btnC;
    FT245_RDn  <= '1';
    FT245_OEn  <= '1';
    
    --datos de la camara
    CAM_Data <= JA(5) & JA(0) & JXADC(7) & JXADC(3) & JXADC(6) & JXADC(2) & JXADC(5) & JXADC(1);
    UserDataIn <= CAM_Data;
    
    -- envio contador
    process(clk)
    begin
        if rising_edge(clk) then
            if cont_freq = 10 then
                cont_freq <= (others => '0');
                if User_rdy_flag = '1' then
                    cont_dato <= cont_dato + 1;
                end if;
            else
                cont_freq <= cont_freq + 1;
            end if;
        end if;
    end process;

    --UserDataIn <= std_logic_vector(cont_dato);

    
end Behavioral;
