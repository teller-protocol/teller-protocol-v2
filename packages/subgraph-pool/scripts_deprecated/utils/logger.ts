export interface Logger {
  log: (msg?: string) => void;
  error: (msg?: string) => void;
}
const logger: Logger = {
  log: function(msg?: string): void {
    console.log(msg);
  },
  error: function(msg?: string): void {
    console.error(msg);
  }
};
export default logger;
