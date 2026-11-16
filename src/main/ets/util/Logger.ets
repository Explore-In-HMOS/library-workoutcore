import { hilog } from '@kit.PerformanceAnalysisKit';

export enum LogLevel {
  DEBUG = 0,
  INFO = 1,
  WARN = 2,
  ERROR = 3,
  OFF = 4
}

export class Logger {
  private static readonly DOMAIN: number = 0x9001;
  private static readonly TAG: string = 'Workout';
  private static readonly FORMAT: string = '%{public}s';
  private static level: LogLevel = LogLevel.INFO;

  private readonly source: string;

  constructor(source: string) {
    this.source = source;
  }

  static setLevel(level: LogLevel): void {
    Logger.level = level;
  }

  d(message: string): void {
    if (Logger.isSuppressed(LogLevel.DEBUG)) {
      return;
    }
    hilog.debug(Logger.DOMAIN, Logger.TAG, Logger.FORMAT, this.line(message));
  }

  i(message: string): void {
    if (Logger.isSuppressed(LogLevel.INFO)) {
      return;
    }
    hilog.info(Logger.DOMAIN, Logger.TAG, Logger.FORMAT, this.line(message));
  }

  w(message: string): void {
    if (Logger.isSuppressed(LogLevel.WARN)) {
      return;
    }
    hilog.warn(Logger.DOMAIN, Logger.TAG, Logger.FORMAT, this.line(message));
  }

  e(message: string): void {
    if (Logger.isSuppressed(LogLevel.ERROR)) {
      return;
    }
    hilog.error(Logger.DOMAIN, Logger.TAG, Logger.FORMAT, this.line(message));
  }

  private static isSuppressed(level: LogLevel): boolean {
    return level < Logger.level || Logger.level === LogLevel.OFF;
  }

  private line(message: string): string {
    return `[${this.source}] ${message}`;
  }
}
