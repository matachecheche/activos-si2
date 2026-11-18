// Desarrollo (npm start / ng serve): ruta relativa /api. El navegador llama al
// propio puerto 4200 y el proxy de proxy.conf.json la redirige al backend en
// localhost:8080. Asi se eliminan los errores CORS y los de IPv6 (status 0).
export const environment = {
  production: false,
  apiUrl: '/api'
};
