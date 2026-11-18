package com.uagrm.activos.auditoria;

import org.aspectj.lang.ProceedingJoinPoint;
import org.aspectj.lang.annotation.Around;
import org.aspectj.lang.annotation.Aspect;
import org.aspectj.lang.reflect.MethodSignature;
import org.springframework.expression.EvaluationContext;
import org.springframework.expression.Expression;
import org.springframework.expression.ExpressionParser;
import org.springframework.expression.spel.standard.SpelExpressionParser;
import org.springframework.expression.spel.support.StandardEvaluationContext;
import org.springframework.stereotype.Component;

import java.lang.reflect.Method;

/** HU-13: aspecto que convierte @Auditable en registros de bitacora. */
@Aspect
@Component
public class AuditoriaAspect {

    private final AuditoriaService auditoriaService;
    private final ExpressionParser parser = new SpelExpressionParser();

    public AuditoriaAspect(AuditoriaService auditoriaService) {
        this.auditoriaService = auditoriaService;
    }

    @Around("@annotation(auditable)")
    public Object auditar(ProceedingJoinPoint pjp, Auditable auditable) throws Throwable {
        Object resultado = pjp.proceed();
        try {
            EvaluationContext ctx = new StandardEvaluationContext();
            Object[] args = pjp.getArgs();
            for (int i = 0; i < args.length; i++) {
                ctx.setVariable("a" + i, args[i]);
            }
            ctx.setVariable("resultado", resultado);
            String id = evaluar(auditable.idExpresion(), ctx);
            String detalle = evaluar(auditable.detalleExpresion(), ctx);
            auditoriaService.registrar(auditable.accion(), auditable.entidad(), id, detalle);
        } catch (Exception e) {
            System.err.println("[AUDITORIA] Error al registrar " + auditable.accion() + ": " + e.getMessage());
        }
        return resultado;
    }

    private String evaluar(String expresion, EvaluationContext ctx) {
        if (expresion == null || expresion.isBlank()) {
            return null;
        }
        try {
            Expression e = parser.parseExpression(expresion);
            Object valor = e.getValue(ctx);
            return valor == null ? null : String.valueOf(valor);
        } catch (org.springframework.expression.EvaluationException e) {
            return null;
        }
    }

    /** Utilidad para leer la anotacion en tiempo de compilacion del IDE. */
    @SuppressWarnings("unused")
    private Method metodo(ProceedingJoinPoint pjp) throws NoSuchMethodException {
        MethodSignature firma = (MethodSignature) pjp.getSignature();
        return pjp.getTarget().getClass().getMethod(firma.getName(), firma.getParameterTypes());
    }
}
