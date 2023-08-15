export interface Logger {
  log: (msg: string) => void;
}
const logger: Logger = {
  log: function(msg: string): void {
    console.log(msg);
  }
};
export default logger;
