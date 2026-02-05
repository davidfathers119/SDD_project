-- 简单UART发送器 (专为TTL设计)
-- 8N1: 8位数据, 无校验, 1停止位
-- 波特率: 38400 @ 25MHz时钟
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_tx_simple is
    generic (
        CLK_FREQ   : integer := 25000000;  -- 25MHz
        BAUD_RATE  : integer := 38400       -- 38400 baud
    );
    port (
        clk        : in  std_logic;
        rst_n      : in  std_logic;
        
        -- 数据接口
        tx_data    : in  std_logic_vector(7 downto 0);
        tx_valid   : in  std_logic;  -- 请求发送一个字节
        tx_ready   : out std_logic;  -- 准备好接收新数据
        
        -- UART TX 线
        tx         : out std_logic
    );
end uart_tx_simple;

architecture rtl of uart_tx_simple is
    -- 波特率分频器: 25MHz / 38400 = 651.04 ≈ 651 (误差0.06%)
    -- 实际波特率: 25MHz / 651 = 38402.46 (误差+0.06%，可接受)
    constant BAUD_DIV : integer := 651;
    
    type state_t is (IDLE, START, DATA, STOP);
    signal state : state_t := IDLE;
    
    signal baud_counter : integer range 0 to BAUD_DIV-1 := 0;
    signal baud_tick    : std_logic := '0';
    
    signal bit_counter  : integer range 0 to 7 := 0;
    signal tx_shift_reg : std_logic_vector(7 downto 0) := (others => '0');
    
begin

    -- 波特率产生器
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            baud_counter <= 0;
            baud_tick <= '0';
        elsif rising_edge(clk) then
            baud_tick <= '0';
            if baud_counter = BAUD_DIV-1 then
                baud_counter <= 0;
                baud_tick <= '1';
            else
                baud_counter <= baud_counter + 1;
            end if;
        end if;
    end process;
    
    -- 发送状态机
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            state <= IDLE;
            tx <= '1';  -- UART idle = 高电平
            tx_ready <= '1';
            tx_shift_reg <= (others => '0');
            bit_counter <= 0;
        elsif rising_edge(clk) then
            case state is
                when IDLE =>
                    tx <= '1';  -- idle 高电平
                    tx_ready <= '1';
                    bit_counter <= 0;
                    
                    if tx_valid = '1' then
                        tx_shift_reg <= tx_data;
                        tx_ready <= '0';
                        state <= START;
                    end if;
                
                when START =>
                    tx <= '0';  -- start bit = 低电平
                    if baud_tick = '1' then
                        state <= DATA;
                    end if;
                
                when DATA =>
                    tx <= tx_shift_reg(0);  -- LSB first
                    if baud_tick = '1' then
                        tx_shift_reg <= '0' & tx_shift_reg(7 downto 1);
                        if bit_counter = 7 then
                            state <= STOP;
                        else
                            bit_counter <= bit_counter + 1;
                        end if;
                    end if;
                
                when STOP =>
                    tx <= '1';  -- stop bit = 高电平
                    if baud_tick = '1' then
                        state <= IDLE;
                    end if;
            end case;
        end if;
    end process;

end rtl;
