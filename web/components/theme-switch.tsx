import { FC, useEffect, useState } from "react";
import { useTheme } from "next-themes";

export interface ThemeSwitchProps {
  className?: string;
}

export const ThemeSwitch: FC<ThemeSwitchProps> = ({ className }) => {
  const [isMounted, setIsMounted] = useState(false);
  const { setTheme, resolvedTheme } = useTheme();

  const isLight = resolvedTheme === "light";

  const handleToggle = () => {
    setTheme(isLight ? "dark" : "light");
  };

  useEffect(() => {
    setIsMounted(true);
  }, []);


  if (!isMounted) return <div aria-hidden className="size-10" />;

  return (
    <button
      aria-label={`Switch to ${isLight ? "dark" : "light"} mode`}
      className={`theme-switch ${className ?? ""}`}
      onClick={handleToggle}
    >
      <span aria-hidden>{isLight ? "☀" : "☾"}</span>
    </button>
  );
};
