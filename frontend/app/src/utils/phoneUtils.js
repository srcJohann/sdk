/**
 * Utilitários para normalização de números de telefone
 * 
 * Conversão entre formatos:
 * - Chatwoot: +5524974023279 (E.164 format)
 * - CRM (Vtiger): 24974023279 (sem country code)
 */

/**
 * Normaliza número de telefone para formato E.164 (+5524974023279)
 * @param {string} phone - Número no formato CRM (24974023279) ou já no E.164
 * @returns {string} - Número no formato E.164 (+5524974023279)
 */
export function normalizeToE164(phone) {
  if (!phone) return '';
  
  // Remove espaços e caracteres especiais exceto +
  let cleaned = phone.trim().replace(/[^\d+]/g, '');
  
  // Já está no formato E.164
  if (cleaned.startsWith('+55')) {
    return cleaned;
  }
  
  // Já tem + mas não é +55
  if (cleaned.startsWith('+')) {
    return cleaned;
  }
  
  // Adiciona +55 se for número brasileiro (começa com DDD)
  // DDDs válidos: 11-99
  const brazilianPattern = /^[1-9]{2}\d{8,9}$/;
  if (brazilianPattern.test(cleaned)) {
    return `+55${cleaned}`;
  }
  
  // Retorna como está se não conseguir identificar
  return cleaned;
}

/**
 * Converte número de E.164 para formato CRM (remove +55)
 * @param {string} phone - Número no formato E.164 (+5524974023279)
 * @returns {string} - Número no formato CRM (24974023279)
 */
export function normalizeToCRM(phone) {
  if (!phone) return '';
  
  // Remove +55 se existir
  let cleaned = phone.trim().replace(/[^\d+]/g, '');
  if (cleaned.startsWith('+55')) {
    return cleaned.substring(3);
  }
  
  if (cleaned.startsWith('+')) {
    return cleaned.substring(1);
  }
  
  return cleaned;
}

/**
 * Valida se o número está no formato E.164 válido
 * @param {string} phone - Número para validar
 * @returns {boolean} - true se válido
 */
export function isValidE164(phone) {
  if (!phone) return false;
  
  // Formato E.164: +[1-9][0-9]{1,14}
  const e164Pattern = /^\+[1-9]\d{1,14}$/;
  return e164Pattern.test(phone.trim());
}

/**
 * Formata número para exibição (adiciona parênteses e traço)
 * @param {string} phone - Número em qualquer formato
 * @returns {string} - Número formatado: +55 (24) 97402-3279
 */
export function formatPhoneDisplay(phone) {
  if (!phone) return '';
  
  const e164 = normalizeToE164(phone);
  
  // Para números brasileiros: +55 (24) 97402-3279
  if (e164.startsWith('+55')) {
    const number = e164.substring(3);
    if (number.length === 11) {
      // Celular: (24) 97402-3279
      return `+55 (${number.substring(0, 2)}) ${number.substring(2, 7)}-${number.substring(7)}`;
    } else if (number.length === 10) {
      // Fixo: (24) 7402-3279
      return `+55 (${number.substring(0, 2)}) ${number.substring(2, 6)}-${number.substring(6)}`;
    }
  }
  
  return e164;
}

/**
 * Extrai DDD do número brasileiro
 * @param {string} phone - Número em qualquer formato
 * @returns {string} - DDD (ex: "24")
 */
export function extractDDD(phone) {
  const normalized = normalizeToCRM(phone);
  if (normalized.length >= 2) {
    return normalized.substring(0, 2);
  }
  return '';
}
