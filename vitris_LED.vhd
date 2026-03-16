-------------------------------------------------------------------------------
-- Title      : LED Control Module with AXI4-Lite Interface
-- Project    : ZC702 LED Control System
-------------------------------------------------------------------------------
-- File       : vitris_LED.vhd
-- Author     : 
-- Created    : 2026-03-16
-- Description: AXI4-Lite Slave接口的LED控制模組
--              接收PS端通過AXI總線發送的控制數據，驅動8個LED
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity vitris_LED is
    Generic (
        -- AXI4-Lite 介面參數
        C_S_AXI_DATA_WIDTH : integer := 32;
        C_S_AXI_ADDR_WIDTH : integer := 4  -- 16個地址空間（4位）
    );
    Port (
        -- LED輸出信號
        LED : out STD_LOGIC_VECTOR(7 downto 0);
        
        -- AXI4-Lite Slave 介面信號
        -- 全局時鐘與複位
        S_AXI_ACLK    : in  STD_LOGIC;
        S_AXI_ARESETN : in  STD_LOGIC;
        
        -- 寫地址通道
        S_AXI_AWADDR  : in  STD_LOGIC_VECTOR(C_S_AXI_ADDR_WIDTH-1 downto 0);
        S_AXI_AWVALID : in  STD_LOGIC;
        S_AXI_AWREADY : out STD_LOGIC;
        
        -- 寫數據通道
        S_AXI_WDATA   : in  STD_LOGIC_VECTOR(C_S_AXI_DATA_WIDTH-1 downto 0);
        S_AXI_WSTRB   : in  STD_LOGIC_VECTOR((C_S_AXI_DATA_WIDTH/8)-1 downto 0);
        S_AXI_WVALID  : in  STD_LOGIC;
        S_AXI_WREADY  : out STD_LOGIC;
        
        -- 寫響應通道
        S_AXI_BRESP   : out STD_LOGIC_VECTOR(1 downto 0);
        S_AXI_BVALID  : out STD_LOGIC;
        S_AXI_BREADY  : in  STD_LOGIC;
        
        -- 讀地址通道
        S_AXI_ARADDR  : in  STD_LOGIC_VECTOR(C_S_AXI_ADDR_WIDTH-1 downto 0);
        S_AXI_ARVALID : in  STD_LOGIC;
        S_AXI_ARREADY : out STD_LOGIC;
        
        -- 讀數據通道
        S_AXI_RDATA   : out STD_LOGIC_VECTOR(C_S_AXI_DATA_WIDTH-1 downto 0);
        S_AXI_RRESP   : out STD_LOGIC_VECTOR(1 downto 0);
        S_AXI_RVALID  : out STD_LOGIC;
        S_AXI_RREADY  : in  STD_LOGIC
    );
end vitris_LED;

architecture Behavioral of vitris_LED is

    -- AXI4-Lite 信號
    signal axi_awaddr  : std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
    signal axi_awready : std_logic;
    signal axi_wready  : std_logic;
    signal axi_bresp   : std_logic_vector(1 downto 0);
    signal axi_bvalid  : std_logic;
    signal axi_araddr  : std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
    signal axi_arready : std_logic;
    signal axi_rdata   : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    signal axi_rresp   : std_logic_vector(1 downto 0);
    signal axi_rvalid  : std_logic;
    
    -- 暫存器定義
    constant ADDR_LED_CONTROL : std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0) := x"0";
    constant ADDR_STATUS      : std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0) := x"4";
    
    signal led_control_reg : std_logic_vector(7 downto 0) := (others => '0');
    signal status_reg      : std_logic_vector(7 downto 0) := (others => '0');
    
    -- 寫操作狀態標誌
    signal slv_reg_wren : std_logic;
    signal slv_reg_rden : std_logic;
    
begin

    -- I/O 連接
    S_AXI_AWREADY <= axi_awready;
    S_AXI_WREADY  <= axi_wready;
    S_AXI_BRESP   <= axi_bresp;
    S_AXI_BVALID  <= axi_bvalid;
    S_AXI_ARREADY <= axi_arready;
    S_AXI_RDATA   <= axi_rdata;
    S_AXI_RRESP   <= axi_rresp;
    S_AXI_RVALID  <= axi_rvalid;
    
    -- LED輸出
    LED <= led_control_reg;
    status_reg <= led_control_reg;  -- 狀態暫存器反映當前LED狀態
    
    ---------------------------------------------------------------------------
    -- 寫地址鎖存流程
    ---------------------------------------------------------------------------
    process (S_AXI_ACLK)
    begin
        if rising_edge(S_AXI_ACLK) then
            if S_AXI_ARESETN = '0' then
                axi_awready <= '0';
                axi_awaddr  <= (others => '0');
            else
                if (axi_awready = '0' and S_AXI_AWVALID = '1' and S_AXI_WVALID = '1') then
                    -- 寫地址準備好
                    axi_awready <= '1';
                    axi_awaddr  <= S_AXI_AWADDR;
                else
                    axi_awready <= '0';
                end if;
            end if;
        end if;
    end process;
    
    ---------------------------------------------------------------------------
    -- 寫數據鎖存流程
    ---------------------------------------------------------------------------
    process (S_AXI_ACLK)
    begin
        if rising_edge(S_AXI_ACLK) then
            if S_AXI_ARESETN = '0' then
                axi_wready <= '0';
            else
                if (axi_wready = '0' and S_AXI_WVALID = '1' and S_AXI_AWVALID = '1') then
                    axi_wready <= '1';
                else
                    axi_wready <= '0';
                end if;
            end if;
        end if;
    end process;
    
    -- 寫暫存器使能信號
    slv_reg_wren <= axi_wready and S_AXI_WVALID and axi_awready and S_AXI_AWVALID;
    
    ---------------------------------------------------------------------------
    -- 暫存器寫入邏輯
    ---------------------------------------------------------------------------
    process (S_AXI_ACLK)
    begin
        if rising_edge(S_AXI_ACLK) then
            if S_AXI_ARESETN = '0' then
                led_control_reg <= (others => '0');
            else
                if (slv_reg_wren = '1') then
                    case axi_awaddr is
                        when ADDR_LED_CONTROL =>
                            -- 寫入LED控制暫存器（僅使用低8位）
                            for byte_index in 0 to (C_S_AXI_DATA_WIDTH/8-1) loop
                                if (S_AXI_WSTRB(byte_index) = '1' and byte_index = 0) then
                                    led_control_reg <= S_AXI_WDATA(7 downto 0);
                                end if;
                            end loop;
                        when others =>
                            -- 其他地址不做處理
                            led_control_reg <= led_control_reg;
                    end case;
                end if;
            end if;
        end if;
    end process;
    
    ---------------------------------------------------------------------------
    -- 寫響應流程
    ---------------------------------------------------------------------------
    process (S_AXI_ACLK)
    begin
        if rising_edge(S_AXI_ACLK) then
            if S_AXI_ARESETN = '0' then
                axi_bvalid <= '0';
                axi_bresp  <= "00";  -- OKAY響應
            else
                if (axi_awready = '1' and S_AXI_AWVALID = '1' and 
                    axi_wready = '1' and S_AXI_WVALID = '1' and 
                    axi_bvalid = '0') then
                    axi_bvalid <= '1';
                    axi_bresp  <= "00";  -- OKAY
                elsif (S_AXI_BREADY = '1' and axi_bvalid = '1') then
                    axi_bvalid <= '0';
                end if;
            end if;
        end if;
    end process;
    
    ---------------------------------------------------------------------------
    -- 讀地址鎖存流程
    ---------------------------------------------------------------------------
    process (S_AXI_ACLK)
    begin
        if rising_edge(S_AXI_ACLK) then
            if S_AXI_ARESETN = '0' then
                axi_arready <= '0';
                axi_araddr  <= (others => '0');
            else
                if (axi_arready = '0' and S_AXI_ARVALID = '1') then
                    axi_arready <= '1';
                    axi_araddr  <= S_AXI_ARADDR;
                else
                    axi_arready <= '0';
                end if;
            end if;
        end if;
    end process;
    
    ---------------------------------------------------------------------------
    -- 讀數據輸出流程
    ---------------------------------------------------------------------------
    process (S_AXI_ACLK)
    begin
        if rising_edge(S_AXI_ACLK) then
            if S_AXI_ARESETN = '0' then
                axi_rvalid <= '0';
                axi_rresp  <= "00";
            else
                if (axi_arready = '1' and S_AXI_ARVALID = '1' and axi_rvalid = '0') then
                    axi_rvalid <= '1';
                    axi_rresp  <= "00";  -- OKAY
                elsif (axi_rvalid = '1' and S_AXI_RREADY = '1') then
                    axi_rvalid <= '0';
                end if;
            end if;
        end if;
    end process;
    
    -- 讀暫存器使能信號
    slv_reg_rden <= axi_arready and S_AXI_ARVALID and (not axi_rvalid);
    
    ---------------------------------------------------------------------------
    -- 暫存器讀取邏輯
    ---------------------------------------------------------------------------
    process (S_AXI_ACLK)
    begin
        if rising_edge(S_AXI_ACLK) then
            if S_AXI_ARESETN = '0' then
                axi_rdata <= (others => '0');
            else
                if (slv_reg_rden = '1') then
                    case axi_araddr is
                        when ADDR_LED_CONTROL =>
                            -- 讀取LED控制暫存器
                            axi_rdata(7 downto 0)  <= led_control_reg;
                            axi_rdata(31 downto 8) <= (others => '0');
                        when ADDR_STATUS =>
                            -- 讀取狀態暫存器
                            axi_rdata(7 downto 0)  <= status_reg;
                            axi_rdata(31 downto 8) <= (others => '0');
                        when others =>
                            axi_rdata <= (others => '0');
                    end case;
                end if;
            end if;
        end if;
    end process;

end Behavioral;
