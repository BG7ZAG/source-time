import { AppError, AppErrorCode } from './Errors';

export interface Result<T> {
  success: boolean;
  data?: T;
  error?: AppError;
}

export function ok<T>(data: T): Result<T> {
  return { success: true, data: data };
}

export function err<T>(code: AppErrorCode, message: string): Result<T> {
  return { success: false, error: { code: code, message: message } };
}
