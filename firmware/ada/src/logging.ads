with HAL;           use HAL;
with STM32.Device; use STM32.Device;
with STM32.GPIO;    use STM32.GPIO;
with STM32.USARTs;  use STM32.USARTs;

package Logging is

   procedure Init;

   procedure Await_Send_Ready (This : USART);

   procedure Put_Blocking (This : in out USART;  Data : UInt16);

   procedure Log (S : String; L :  Integer := 1; Deindent : Integer := 0);

end Logging;
