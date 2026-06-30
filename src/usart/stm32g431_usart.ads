with Usart_Types;
with STM32G431xx;
with STM32G431xx.USART;
with System.Storage_Elements; use System.Storage_Elements;

--  STM32G431_USART models a physical USART peripheral (USART1, USART2, etc.).
--  The instantiation IS the bus. There is no Device type.
--
--  USART is a one-level abstraction: bus = device.

generic
   Periph         : not null access STM32G431xx.USART.USART_Peripheral;
   with function  Get_Clock   return Natural;
   with procedure RCC_Enable;
   with procedure RCC_Reset;
package STM32G431_USART is

   --  Control-plane hooks

   procedure Init       (Cfg : Usart_Types.Usart_Config);
   procedure Enable;
   function  Is_Enabled return Boolean;
   procedure Disable;
   procedure Reset;

   --  Data-plane hooks

   procedure Tx_Push (B        : Storage_Element;
                      Accepted : out Boolean);
   procedure Rx_Pop  (B         : out Storage_Element;
                      Available : out Boolean);

end STM32G431_USART;