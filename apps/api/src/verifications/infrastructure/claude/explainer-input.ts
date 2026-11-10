import { Decimal } from 'decimal.js';
import { currencyDecimals } from '../../../shared/domain/money.js';
import type { AuditFacts } from '../../domain/statement-extractor.js';

const VERDICT_ES: Record<AuditFacts['verdict'], string> = {
  MATCH: 'coincide',
  UNDERPAID: 'te pagaron de menos',
  OVERPAID: 'te pagaron de más',
};

const BALANCE_SOURCE_ES = {
  STATEMENT: 'el estado de cuenta',
  PREVIOUS_VERIFICATION: 'la auditoría del mes anterior',
  USER: 'el dato que indicó el usuario',
  PREVIOUS_STATEMENT: 'el estado de cuenta del mes anterior',
} as const;

const WARNING_ES: Record<string, string> = {
  REWARD_BALANCE_INCONSISTENT:
    'el saldo anterior no cuadra con el actual y lo ganado en el mes resultó negativo',
  REPORTED_VALUE_MAY_BE_CUMULATIVE:
    'la cifra reportada parece un saldo acumulado y no lo ganado en el periodo',
  NO_EXCHANGE_RATE:
    'hubo compras en moneda extranjera que se excluyeron por falta de tipo de cambio',
  REPORTED_UNIT_DIFFERS_FROM_CARD:
    'la unidad del programa difiere de la configurada en la tarjeta',
};

/** "1526.8" -> "1,526.80" (digits grouped; decimals of the currency). */
export function formatAmount(value: string, currency: string | null): string {
  const decimals = currency ? currencyDecimals(currency) : 2;
  const fixed = new Decimal(value).toFixed(decimals);
  const [int, frac] = fixed.split('.') as [string, string | undefined];
  const negative = int.startsWith('-');
  const grouped = int.replace('-', '').replace(/\B(?=(\d{3})+(?!\d))/g, ',');
  return `${negative ? '-' : ''}${grouped}${frac ? `.${frac}` : ''}`;
}

/** "HNL 1,526.84"; points are "1,526 puntos". */
export function formatMoney(value: string, currency: string | null): string {
  return currency
    ? `${currency} ${formatAmount(value, currency)}`
    : `${formatAmount(value, null)} puntos`;
}

/**
 * What the explainer model receives: Spanish wording only (no enum names), and
 * money already formatted, so it has nothing to compute or translate.
 */
export function toExplainerInput(facts: AuditFacts) {
  const rewardCurrency =
    facts.rewardUnit === 'POINTS'
      ? null
      : (facts.rewardCurrency ?? facts.primaryCurrency);
  const primary = facts.primaryCurrency;
  const capCurrency = facts.rewardUnit === 'POINTS' ? null : primary;
  return {
    resultado: VERDICT_ES[facts.verdict],
    recompensa: facts.rewardUnit === 'POINTS' ? 'puntos' : 'dinero',
    programa: facts.programName,
    reportadoPorElBanco: formatMoney(facts.reported, rewardCurrency),
    esperado: formatMoney(facts.expected, rewardCurrency),
    diferencia: formatMoney(facts.difference, rewardCurrency),
    tolerancia: formatMoney(facts.tolerance, rewardCurrency),
    esperadoEnMonedaDeLaTarjeta:
      facts.expectedInPrimaryCurrency !== null
        ? formatMoney(facts.expectedInPrimaryCurrency, primary)
        : null,
    cifraReportadaPor:
      facts.reportedSource === 'OVERRIDE'
        ? 'el usuario'
        : 'el estado de cuenta',
    desglosePorCategoria: facts.breakdown.map((l) => ({
      categoria: l.category ?? 'Resto de compras',
      tasaPorcentaje: l.ratePercent,
      gasto: formatMoney(l.spend, primary),
      recompensaEsperada: formatMoney(
        l.expectedReward,
        facts.rewardUnit === 'POINTS' ? null : primary,
      ),
      topeMensualAplicado: l.capped,
      topeMensual: l.monthlyCap
        ? formatMoney(
            l.monthlyCap,
            facts.rewardUnit === 'POINTS' ? null : primary,
          )
        : null,
    })),
    topeDeLaTarjeta: facts.rewardCap
      ? {
          explicacion:
            'la tarjeta tiene un tope de recompensa por estado de cuenta y se alcanzó: lo esperado se limitó a ese tope',
          tope: formatMoney(facts.rewardCap.cap, capCurrency),
          esperadoSinTope: formatMoney(facts.rewardCap.uncapped, capCurrency),
          esperadoConTope: formatMoney(facts.rewardCap.capped, capCurrency),
        }
      : null,
    derivacionDeLoGanado: facts.rewardReporting
      ? {
          explicacion:
            'el banco informa un saldo acumulado; lo ganado en el mes se calculó como saldo actual menos saldo anterior más lo redimido más lo vencido',
          saldoActual: facts.rewardReporting.currentBalance
            ? formatMoney(facts.rewardReporting.currentBalance, rewardCurrency)
            : null,
          saldoAnterior: facts.rewardReporting.previousBalance
            ? formatMoney(facts.rewardReporting.previousBalance, rewardCurrency)
            : null,
          origenDelSaldoAnterior: facts.rewardReporting.previousBalanceSource
            ? BALANCE_SOURCE_ES[facts.rewardReporting.previousBalanceSource]
            : null,
          redimidoEnElMes: formatMoney(
            facts.rewardReporting.redeemedInPeriod,
            rewardCurrency,
          ),
          vencidoEnElMes: formatMoney(
            facts.rewardReporting.expiredInPeriod,
            rewardCurrency,
          ),
          ganadoEnElMes: facts.rewardReporting.earned
            ? formatMoney(facts.rewardReporting.earned, rewardCurrency)
            : null,
        }
      : null,
    comprasExcluidasPorFaltaDeTipoDeCambio: facts.excludedForeignLines,
    avisos: facts.warningCodes.flatMap((c) =>
      WARNING_ES[c] ? [WARNING_ES[c]!] : [],
    ),
  };
}
