// See the Tailwind configuration guide for advanced usage
// https://tailwindcss.com/docs/configuration

module.exports = {
  content: ["./src/**/*.{html,gleam}"],
  theme: {
    extend: {
      fontFamily: {
        sans: ["DM Sans"],
      },
    },
  },
  daisyui: {
    themes: [
      {
        mytheme: {
          "primary": "#d895ee",
          "primary-content": "#151515",
          "secondary": "#ee95d2",
          "secondary-content": "#151515",
          "base-100": "#151515",
          "base-200": "#181818",
          "base-300": "#202020",
          "base-content": "#d8d0d5",
          "info": "#97d0e8",
          "success": "#9be099",
          "warning": "#e8d097",
          "error": "#ee9598",
        },
      },
    ],
  },
  plugins: [require("daisyui")],
};
