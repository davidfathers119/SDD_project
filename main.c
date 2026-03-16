/**
 * @file    main.c
 * @brief   LED控制系統 - ARM端應用程式
 * @details 通過UART接收PC端輸入，控制PL端LED
 * @date    2026-03-16
 */

#include <stdio.h>
#include "platform.h"
#include "xil_printf.h"
#include "xparameters.h"
#include "xuartps.h"
#include "xil_io.h"

/**************************** 硬體參數定義 ************************************/
// LED控制器基地址（需根據Vivado Address Editor調整）
#define LED_CONTROLLER_BASE    XPAR_VITRIS_LED_0_S_AXI_BASEADDR

// 暫存器偏移
#define LED_CONTROL_REG_OFFSET 0x00
#define STATUS_REG_OFFSET      0x04

// UART設備ID
#define UART_DEVICE_ID         XPAR_XUARTPS_0_DEVICE_ID

/**************************** 全局變數 ****************************************/
XUartPs UartInst;      // UART實例

/**************************** 函數原型 ****************************************/
int  init_uart(void);
void set_led(u8 value);
u8   get_led_status(void);
void process_input(u8 input_char);

/******************************************************************************/
/**
 * @brief  主函數
 * @return 成功返回0
 */
int main(void)
{
    int status;
    u8 recv_char;
    
    init_platform();
    
    print("\r\n");
    print("===============================================\r\n");
    print("  LED Control System - ZC702\r\n");
    print("  版本: 1.0\r\n");
    print("===============================================\r\n");
    print("\r\n");
    
    // 初始化UART
    status = init_uart();
    if (status != XST_SUCCESS) {
        xil_printf("UART初始化失敗！\r\n");
        return XST_FAILURE;
    }
    xil_printf("UART初始化成功\r\n");
    
    // 初始化LED（全滅）
    set_led(0);
    xil_printf("LED已初始化\r\n");
    xil_printf("\r\n");
    xil_printf("請輸入數字 (0-8) 來控制LED:\r\n");
    xil_printf("  0 = 全滅\r\n");
    xil_printf("  1-8 = 對應的LED模式\r\n");
    xil_printf("\r\n");
    
    // 主循環
    while (1) {
        // 檢查是否有接收數據
        if (XUartPs_IsReceiveData(UartInst.Config.BaseAddress)) {
            // 接收一個字符
            recv_char = XUartPs_RecvByte(UartInst.Config.BaseAddress);
            
            // 回顯字符
            XUartPs_SendByte(UartInst.Config.BaseAddress, recv_char);
            
            // 處理輸入
            process_input(recv_char);
        }
    }
    
    cleanup_platform();
    return 0;
}

/******************************************************************************/
/**
 * @brief  初始化UART
 * @return XST_SUCCESS 或 XST_FAILURE
 */
int init_uart(void)
{
    int status;
    XUartPs_Config *uart_config;
    
    // 查找UART配置
    uart_config = XUartPs_LookupConfig(UART_DEVICE_ID);
    if (uart_config == NULL) {
        return XST_FAILURE;
    }
    
    // 初始化UART驅動
    status = XUartPs_CfgInitialize(&UartInst, uart_config, uart_config->BaseAddress);
    if (status != XST_SUCCESS) {
        return XST_FAILURE;
    }
    
    // 設置鮑率 115200
    XUartPs_SetBaudRate(&UartInst, 115200);
    
    return XST_SUCCESS;
}

/******************************************************************************/
/**
 * @brief  設置LED狀態
 * @param  value: LED控制值（0-255）
 */
void set_led(u8 value)
{
    // 寫入LED控制暫存器
    Xil_Out32(LED_CONTROLLER_BASE + LED_CONTROL_REG_OFFSET, (u32)value);
}

/******************************************************************************/
/**
 * @brief  讀取LED狀態
 * @return 當前LED狀態
 */
u8 get_led_status(void)
{
    u32 reg_value;
    
    // 讀取狀態暫存器
    reg_value = Xil_In32(LED_CONTROLLER_BASE + STATUS_REG_OFFSET);
    
    return (u8)(reg_value & 0xFF);
}

/******************************************************************************/
/**
 * @brief  處理接收到的輸入字符
 * @param  input_char: 輸入字符
 */
void process_input(u8 input_char)
{
    u8 led_value;
    u8 current_status;
    
    // 檢查是否為數字字符 '0'-'8'
    if (input_char >= '0' && input_char <= '8') {
        // 轉換字符為數值
        led_value = input_char - '0';
        
        // 設置LED
        set_led(led_value);
        
        // 讀取並驗證狀態
        current_status = get_led_status();
        
        // 輸出確認信息
        xil_printf("\r\n輸入值: %d\r\n", led_value);
        xil_printf("LED狀態: 0x%02X (二進制: ", current_status);
        
        // 輸出二進制表示
        for (int i = 7; i >= 0; i--) {
            if (current_status & (1 << i)) {
                xil_printf("1");
            } else {
                xil_printf("0");
            }
        }
        xil_printf(")\r\n");
        
        // 顯示哪些LED點亮
        xil_printf("點亮的LED: ");
        int led_on = 0;
        for (int i = 0; i < 8; i++) {
            if (current_status & (1 << i)) {
                if (led_on > 0) {
                    xil_printf(", ");
                }
                xil_printf("LED%d", i);
                led_on++;
            }
        }
        if (led_on == 0) {
            xil_printf("無");
        }
        xil_printf("\r\n\r\n");
        
    } else if (input_char == '\r' || input_char == '\n') {
        // 忽略回車換行
    } else {
        // 無效輸入
        xil_printf("\r\n錯誤: 無效輸入 '%c' (0x%02X)\r\n", input_char, input_char);
        xil_printf("請輸入 0-8 之間的數字\r\n\r\n");
    }
}
