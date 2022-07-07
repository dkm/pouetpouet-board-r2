with HAL;           use HAL;
with STM32.Device; use STM32.Device;
with STM32.GPIO;    use STM32.GPIO;
with STM32.USARTs;  use STM32.USARTs;

package body Logging is

   TX_Pin : constant GPIO_Point := PB6;
   RX_Pin : constant GPIO_Point := PB7;

   procedure Init is
   begin
      Enable_Clock (USART_1);
      Enable_Clock (RX_Pin & TX_Pin);

      Configure_IO
        (RX_Pin & TX_Pin,
         (Mode           => Mode_AF,
          AF             => GPIO_B_AF_USART1_0,
          Resistors      => Pull_Up,
          AF_Speed       => Speed_50MHz,
          AF_Output_Type => Push_Pull));

      Disable (USART_1);

      Set_Oversampling_Mode (USART_1, Oversampling_By_16);
      Set_Baud_Rate    (USART_1, 115200);
      Set_Mode         (USART_1, Tx_Rx_Mode);
      Set_Stop_Bits    (USART_1, Stopbits_1);
      Set_Word_Length  (USART_1, Word_Length_8);
      Set_Parity       (USART_1, No_Parity);
      Set_Flow_Control (USART_1, No_Flow_Control);

      Enable (USART_1);

   end Init;

   procedure Await_Send_Ready (This : USART) is
   begin
      loop
         exit when Tx_Ready (This);
      end loop;
   end Await_Send_Ready;

   procedure Put_Blocking (This : in out USART;  Data : UInt16) is
   begin
      Await_Send_Ready (This);
      Transmit (This, UInt9 (Data));
   end Put_Blocking;

   procedure Log (S : String; L :  Integer := 1; Deindent : Integer := 0) is
   begin

      for C of S loop
         Put_Blocking (USART_1, Character'Pos (C));
      end loop;

      Put_Blocking (USART_1, UInt16 (13)); -- CR
      Put_Blocking (USART_1, UInt16 (10)); -- LF
   end Log;
end Logging;
