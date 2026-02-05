-- 简单UART接收器 (专为TTL设计)
-- 8N1: 8位数据, 无校验, 1停止位
-- 波特率: 38400 @ 25MHz时钟
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_rx_simple is
    generic (
        CLK_FREQ   : integer := 25000000;  -- 25MHz
        BAUD_RATE  : integer := 38400       -- 38400 baud
    );
    port (
        clk        : in  std_logic;
        rst_n      : in  std_logic;
        
        -- 数据接口
        rx_data    : out std_logic_vector(7 downto 0);
        rx_valid   : out std_logic;  -- 1-cycle pulse: 接收到一个字节
        
        -- UART RX 线
        rx         : in  std_logic
    );
end uart_rx_simple;

architecture rtl of uart_rx_simple is
    -- 波特率分频器: 25MHz / 38400 = 651
    -- 为了在start bit中间采样，使用16x过采样
    constant OVERSAMPLE : integer := 16;
    constant BAUD_DIV : integer := CLK_FREQ / (BAUD_RATE * OVERSAMPLE);
    
    type state_t is (IDLE, START, DATA, STOP);
    signal state : state_t := IDLE;
    
    signal baud_counter : integer range 0 to BAUD_DIV-1 := 0;
    signal baud_tick    : std_logic := '0';
    
    signal sample_counter : integer range 0 to OVERSAMPLE-1 := 0;
    signal sample_tick    : std_logic := '0';
    
    signal bit_counter  : integer range 0 to 7 := 0;
    signal rx_shift_reg : std_logic_vector(7 downto 0) := (others => '0');
    
    -- RX线同步
    signal rx_sync : std_logic_vector(1 downto 0) := (others => '1');
    
begin

    -- 输入同步 (防止亚稳态)
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            rx_sync <= (others => '1');
        elsif rising_edge(clk) then
            rx_sync <= rx_sync(0) & rx;
        end if;
    end process;
    
    -- 波特率产生器 (16x过采样)
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            baud_counter <= 0;
            baud_tick <= '0';
        elsif rising_edge(clk) then
            baud_tick <= '0';
            if state = IDLE then
                baud_counter <= 0;
            elsif baud_counter = BAUD_DIV-1 then
                baud_counter <= 0;
                baud_tick <= '1';
            else
                baud_counter <= baud_counter + 1;
            end if;
        end if;
    end process;
    
    -- 采样计数器 (在bit中间采样)
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            sample_counter <= 0;
            sample_tick <= '0';
        elsif rising_edge(clk) then
            sample_tick <= '0';
            if baud_tick = '1' then
                if sample_counter = OVERSAMPLE-1 then
                    sample_counter <= 0;
                    sample_tick <= '1';  -- 在bit中间采样
                else
                    sample_counter <= sample_counter + 1;
                end if;
            end if;
        end if;
    end process;
    
    -- 接收状态机
    process(clk, rst_n)
    begin
        if rst_n = '0' then
            state <= IDLE;
            rx_valid <= '0';
            rx_data <= (others => '0');
            rx_shift_reg <= (others => '0');
            bit_counter <= 0;
        elsif rising_edge(clk) then
            rx_valid <= '0';  -- 默认无效
            
            case state is
                when IDLE =>
                    bit_counter <= 0;
                    sample_counter <= 0;
                    
                    -- 检测start bit (下降沿: 从1到0)
                    if rx_sync(1) = '0' then
                        state <= START;
                    end if;
                
                when START =>
                    -- 在start bit中间采样验证
                    if sample_tick = '1' then
                        if rx_sync(1) = '0' then  -- 确认是start bit
                            state <= DATA;
                        else  -- 假start bit
                            state <= IDLE;
                        end if;
                    end if;
                
                when DATA =>
                    if sample_tick = '1' then
                        rx_shift_reg <= rx_sync(1) & rx_shift_reg(7 downto 1);  -- LSB first
                        if bit_counter = 7 then
                            state <= STOP;
                        else
                            bit_counter <= bit_counter + 1;
                        end if;
                    end if;
                
                when STOP =>
                    if sample_tick = '1' then
                        if rx_sync(1) = '1' then  -- 确认stop bit
                            rx_data <= rx_shift_reg;
                            rx_valid <= '1';  -- 接收完成
                        end if;
                        state <= IDLE;
                    end if;
            end case;
        end if;
    end process;

end rtl;
