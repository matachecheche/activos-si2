package com.uagrm.activos.tenant;

import org.hibernate.context.spi.CurrentTenantIdentifierResolver;
import org.springframework.stereotype.Component;

/**
 * HU-11: puente entre el TenantContext de la peticion y el multitenancy
 * discriminador nativo de Hibernate (@TenantId). Hibernate exige un
 * identificador no nulo en toda sesion; por eso el contexto sin empresa
 * (arranque, Super Admin, registro publico, login) usa el centinela ROOT=0,
 * que isRoot() marca para no aplicar el filtro _tenantId. Las empresas reales
 * empiezan en id=1, asi que 0 nunca colisiona.
 */
@Component
public class TenantResolver implements CurrentTenantIdentifierResolver<Long> {

    public static final Long ROOT = 0L;

    @Override
    public Long resolveCurrentTenantIdentifier() {
        Long id = TenantContext.getEmpresaId();
        return id != null ? id : ROOT;
    }

    @Override
    public boolean validateExistingCurrentSessions() {
        return false;
    }

    @Override
    public boolean isRoot(Long tenantId) {
        return ROOT.equals(tenantId);
    }
}
