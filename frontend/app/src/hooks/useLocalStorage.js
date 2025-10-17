import { useState } from 'react';

const useLocalStorage = (key, initialValue) => {
  const [storedValue, setStoredValue] = useState(() => {
    try {
      const item = window.localStorage.getItem(key);
      return item ? JSON.parse(item) : initialValue;
    } catch (error) {
      console.error(`Erro ao ler localStorage para key "${key}":`, error);
      return initialValue;
    }
  });

  const setValue = (value) => {
    try {
      const valueToStore = value instanceof Function ? value(storedValue) : value;
      
      // Debug log para mensagens
      if (key === 'sdr_messages') {
        console.log(`💾 [useLocalStorage] Salvando ${valueToStore.length} mensagens`);
        const lastMsg = valueToStore[valueToStore.length - 1];
        if (lastMsg) {
          console.log(`   Última: [${lastMsg.sender}] ${lastMsg.text?.substring(0, 50)}...`);
        }
      }
      
      setStoredValue(valueToStore);
      window.localStorage.setItem(key, JSON.stringify(valueToStore));
    } catch (error) {
      console.error(`Erro ao salvar no localStorage para key "${key}":`, error);
    }
  };

  return [storedValue, setValue];
};

export default useLocalStorage;