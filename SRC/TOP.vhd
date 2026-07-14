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
alias FT245_RXEn : STD_LOGIC is JC(0); --JC1, K17 , -i
alias FT245_RDn  : STD_LOGIC is JC(1); --JC2, M18 , -o
alias FT245_SIWUn  : STD_LOGIC is JC(2); --JC3, N17 , -o
alias FT245_OEn  : STD_LOGIC is JC(3); --JC4, P18 , -o
alias FT245_TXEn : STD_LOGIC is JC(4); --JC7, L17 , -o
alias FT245_WRn  : STD_LOGIC is JC(5); --JC8, M19 , -o
alias CLOKOUT  : STD_LOGIC is JC(6); --JC9, P17 , -i
alias PWRSAVn  : STD_LOGIC is JC(7); --JC10, R18 , -o


--señales usadas en FT245_IF, lado FPGA
signal UserDataIn  : STD_LOGIC_VECTOR(7 downto 0);
signal User_wr_en  : STD_LOGIC;
signal User_rdy_flag  : STD_LOGIC;
signal MRST   : STD_LOGIC := '0';
--señales usadas en FT245_IF, lado conector
signal FT245_D_s   : STD_LOGIC_VECTOR(7 downto 0);
signal FT245_TXEn_s   : STD_LOGIC;
signal FT245_WRn_s    : STD_LOGIC;


signal cont_dato  : unsigned(7 downto 0) := (others => '0');
begin
-- envio contador al FT245 lo mas rapido posible
    process(clk)
    begin
        if rising_edge(clk) then
            if User_rdy_flag = '1' then
                User_wr_en <= '1';
                cont_dato <= cont_dato + 1;
            else
                User_wr_en <= '0';
            end if;
        end if;
    end process;

    UserDataIn <= std_logic_vector(cont_dato);


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

    -- conexionado del FT245_IF con el conector JB y JC.
    --FT245_D <= FT245_D_s;
    FT245_D(0) <= FT245_D_s(0);
    FT245_D(1) <= FT245_D_s(2);
    FT245_D(2) <= FT245_D_s(4);
    FT245_D(3) <= FT245_D_s(6);
    FT245_D(4) <= FT245_D_s(1);
    FT245_D(5) <= FT245_D_s(3);
    FT245_D(6) <= FT245_D_s(5);
    FT245_D(7) <= FT245_D_s(7);
    FT245_WRn <= FT245_WRn_s;
    FT245_TXEn_s <= FT245_TXEn;
    FT245_RDn <= '1';  -- no usados
    FT245_SIWUn <= '1';  -- no usados
    FT245_OEn <= '1';  -- no usados
    PWRSAVn <= '0';  -- no usados

    
end Behavioral;
