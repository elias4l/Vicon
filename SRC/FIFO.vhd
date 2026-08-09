----------------------------------------------------------------------------------
-- FIFO BRAM. PUSH y POP se pueden activar a la vez.
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity FIFO is
--EC32. El interfaz del módulo FIFO debe incluir los genéricos B y W.
  generic (
    B : integer := 17;   -- anchura de bus de direcciones de la RAM interna. 2^15 = 32768 bytes = 32 KB. 2^17 = 128 KB.
    W : integer := 8);  -- anchura de los buses de datos (DIN y DOUT).
        Port (
            CLK   : in std_logic;
            RST   : in std_logic;
            DIN   : in std_logic_vector(W-1 downto 0);
            PUSH  : in std_logic;
            FULL  : out std_logic;
            DOUT  : out std_logic_vector(W-1 downto 0);
            POP   : in std_logic;
            EMPTY : out std_logic);
end FIFO;

architecture Behavioral of FIFO is
--EC32. Declarar el tipo array para modelar el bloque de memoria, en función de los dos genéricos declarados (B y W).
  type reg_file_type is array (2**B - 1 downto 0) of std_logic_vector (W-1 downto 0);
--EC32. Declarar la señal necesaria para modelo de RAM, cuyo tipo será el tipo array que acabamos de declarar.
  signal RAM : reg_file_type;
-- EC32. La señal de habilitación de escritura también es ahora una señal interna que ha de generar la lógica de control.
    signal wr_en: std_logic;
    signal rd_en: std_logic;
    signal wr_ptr: std_logic_vector(B-1 downto 0) := (others => '0');  -- punteros de lectura y escritura en la FIFO.
    signal rd_ptr: std_logic_vector(B-1 downto 0) := (others => '0');
    
    signal full_aux: std_logic; -- Señales que representan las salidas FULL y EMPTY.
    signal empty_aux: std_logic;-- Estas dos señales de estado deben ser NO REGISTRADAS.
-- EC32. El elemento clave es un contador UP/DOWN que nos permitirá llevar la cuenta del número de palabras almacenadas en la FIFO begin.
    signal contador: unsigned(B downto 0) := (others => '0'); -- La RAM va de 0 a 2**B-1 direcciones, pero el contador va de 0(EMPTY) a 2**B (FULL), por lo que se usan B + 1 bits.

begin
--TFM. Modelar memoria RAM interna basada en BRAM. No usa reset (sino seria FF) y la escritura es sincrona (sino es LUTram).
    process(CLK)
    begin
      if rising_edge(CLK) then
        if wr_en = '1' then -- write port, en la memoria se escribe solo cuando está HABILITADA.
          RAM(to_integer(unsigned(wr_ptr))) <= DIN; -- Los indices del array son enteros.
        end if;
        -- read port, de la memoria se lee siempre, sin necesidad de habilitación. TFM. + de forma sincrona (BRAM).
        DOUT <= RAM(to_integer(unsigned(rd_ptr)));
      end if;
    end process;


--EC32. Modelado del Bloque de Lógica de Control.
    process (CLK)
        begin
        if (CLK'event and CLK='1') then
            if (RST = '1') then --EC32. ambos contadores deben ponerse a 0, de manera SÍNCRONA, cuando se activa la entrada RST.
                wr_ptr <= (others => '0');
                rd_ptr <= (others => '0');
            elsif wr_en = '1' and PUSH = '1' then --EC32. el puntero de escritura se incrementa solo cuando se activa la habilitación de escritura.
                if wr_ptr = std_logic_vector(to_unsigned(2**B-1, B)) then -- tamaño del bus de direcciones es B.
                    wr_ptr <= (others => '0');  -- memoria RAM circular.
                else
                    wr_ptr <= std_logic_vector(unsigned(wr_ptr) + 1);
                end if;
            elsif rd_en = '1' and POP = '1' then --EC32. el puntero de lectura se incrementa solo cuando se activa la habilitación de lectura.
                if rd_ptr = std_logic_vector(to_unsigned(2**B-1, B)) then
                    rd_ptr <= (others => '0');
                else
                    rd_ptr <= std_logic_vector(unsigned(rd_ptr) + 1);
                end if;
            end if;
        end if;
    end process;

--EC32. La habilitación de escritura se debe activar solo cuando se activa la entrada PUSH y la FIFO NO está llena (FULL).
-- La habilitación de lectura se debe activar solo cuando se activa la entrada POP y la FIFO NO está vacía (EMPTY).
-- Estas dos señales de habilitación deben ser NO REGISTRADAS.
    wr_en <= '1' when (PUSH = '1' and full_aux = '0') else '0';
    rd_en <= '1' when (POP = '1' and empty_aux = '0') else '0';


--EC32. Modelado del Bloque de Lógica de Estado. Generar las señales de estado de salida, FULL y EMPTY
    process (CLK)
        begin
        if (rising_edge(CLK)) then
            if (RST = '1') then --EC32. El contador debe ponerse a 0, de manera SÍNCRONA, cuando se activa RST.
                contador <= (others => '0');
            elsif wr_en = '1' and rd_en = '0' then --EC32. El contador se incrementa solo cuando está HABILITADA la escritura y NO está HABILITADA la lectura.
                contador <= contador + 1;
            elsif rd_en = '1' and wr_en = '0' then --EC32. El contador se decrementa solo cuando está HABILITADA la lectura y NO está HABILITADA la escritura.
                contador <= contador - 1;
            else -- en el resto de circunstancias el contador no se modifica.
            end if;
        end if;
    end process;
    
    empty_aux <= '1' when contador = 0 else '0';
    full_aux <= '1' when contador = (2**B) else '0';    -- EC23. Valor maximo es 2**B y no 2**B-1.
    EMPTY <= empty_aux;
    FULL <= full_aux;


end Behavioral;
