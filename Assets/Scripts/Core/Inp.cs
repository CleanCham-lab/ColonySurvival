using UnityEngine;
using UnityEngine.InputSystem;

namespace CS
{
    /// 키보드·게임패드 입력 한곳에 모음
    public static class Inp
    {
        static Keyboard K => Keyboard.current;
        static Gamepad G => Gamepad.current;

        public static Vector2 Move()
        {
            Vector2 v = Vector2.zero;
            var k = K;
            if (k != null)
            {
                if (k.aKey.isPressed || k.leftArrowKey.isPressed) v.x -= 1;
                if (k.dKey.isPressed || k.rightArrowKey.isPressed) v.x += 1;
                if (k.sKey.isPressed || k.downArrowKey.isPressed) v.y -= 1;
                if (k.wKey.isPressed || k.upArrowKey.isPressed) v.y += 1;
            }
            var g = G;
            if (g != null)
            {
                Vector2 s = g.leftStick.ReadValue();
                if (s.sqrMagnitude > 0.05f) v += s;
                v += g.dpad.ReadValue();
            }
            return Vector2.ClampMagnitude(v, 1f);
        }

        static bool Key(Key a) { var k = K; return k != null && k[a].wasPressedThisFrame; }
        public static bool Dash => Key(UnityEngine.InputSystem.Key.Space) || Key(UnityEngine.InputSystem.Key.LeftShift) || (G != null && (G.buttonSouth.wasPressedThisFrame || G.rightTrigger.wasPressedThisFrame));
        public static bool Ultimate => Key(UnityEngine.InputSystem.Key.Q) || Key(UnityEngine.InputSystem.Key.E) || (G != null && (G.buttonNorth.wasPressedThisFrame || G.leftTrigger.wasPressedThisFrame));
        public static bool Pause => Key(UnityEngine.InputSystem.Key.Escape) || Key(UnityEngine.InputSystem.Key.P) || (G != null && G.startButton.wasPressedThisFrame);
        public static bool Confirm => Key(UnityEngine.InputSystem.Key.Enter) || Key(UnityEngine.InputSystem.Key.NumpadEnter) || Key(UnityEngine.InputSystem.Key.Space) || (G != null && G.buttonSouth.wasPressedThisFrame);
        public static bool Back => Key(UnityEngine.InputSystem.Key.Escape) || Key(UnityEngine.InputSystem.Key.Backspace) || (G != null && G.buttonEast.wasPressedThisFrame);
        public static bool Reroll => Key(UnityEngine.InputSystem.Key.R) || (G != null && G.buttonWest.wasPressedThisFrame);
        public static bool Up => Key(UnityEngine.InputSystem.Key.W) || Key(UnityEngine.InputSystem.Key.UpArrow) || (G != null && (G.dpad.up.wasPressedThisFrame || G.leftStick.up.wasPressedThisFrame));
        public static bool Down => Key(UnityEngine.InputSystem.Key.S) || Key(UnityEngine.InputSystem.Key.DownArrow) || (G != null && (G.dpad.down.wasPressedThisFrame || G.leftStick.down.wasPressedThisFrame));
        public static bool Left => Key(UnityEngine.InputSystem.Key.A) || Key(UnityEngine.InputSystem.Key.LeftArrow) || (G != null && (G.dpad.left.wasPressedThisFrame || G.leftStick.left.wasPressedThisFrame));
        public static bool Right => Key(UnityEngine.InputSystem.Key.D) || Key(UnityEngine.InputSystem.Key.RightArrow) || (G != null && (G.dpad.right.wasPressedThisFrame || G.leftStick.right.wasPressedThisFrame));
        public static int Choice
        {
            get
            {
                if (Key(UnityEngine.InputSystem.Key.Digit1) || Key(UnityEngine.InputSystem.Key.Numpad1)) return 0;
                if (Key(UnityEngine.InputSystem.Key.Digit2) || Key(UnityEngine.InputSystem.Key.Numpad2)) return 1;
                if (Key(UnityEngine.InputSystem.Key.Digit3) || Key(UnityEngine.InputSystem.Key.Numpad3)) return 2;
                return -1;
            }
        }
        public static bool Fullscreen => Key(UnityEngine.InputSystem.Key.F11) || (K != null && K.fKey.wasPressedThisFrame && (K.leftCommandKey.isPressed || K.rightCommandKey.isPressed) && K.leftCtrlKey.isPressed);
        public static Vector2 MousePos => Mouse.current != null ? Mouse.current.position.ReadValue() : new Vector2(-1, -1);
        public static bool Click => Mouse.current != null && Mouse.current.leftButton.wasPressedThisFrame;
    }
}
